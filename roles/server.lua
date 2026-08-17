local M = {}
local network = require("core.network")
local loader = require("core.module_loader")

local function freshEnvelope(state)
    return {
        schema = 1,
        serverId = os.getComputerID(),
        generated = os.epoch("utc"),
        state = state
    }
end

function M.run(cfg)
    network.host(cfg)
    local modules = loader.discover("modules")
    local state = loader.readAll(modules, {})
    local lastModuleScan = os.epoch("utc")
    print("KIMI Base Server online - ID " .. os.getComputerID())
    print("Modules: " .. tostring(#(function() local t={} for k in pairs(modules) do t[#t+1]=k end return t end)()))

    local timer = os.startTimer(0.5)
    while true do
        local e = { os.pullEvent() }
        if e[1] == "timer" and e[2] == timer then
            state = loader.readAll(modules, state)
            local now = os.epoch("utc")
            if now - lastModuleScan >= 10000 then
                modules = loader.discover("modules")
                lastModuleScan = now
            end
            timer = os.startTimer(0.5)

        elseif e[1] == "rednet_message" then
            local sender, msg, protocol = e[2], e[3], e[4]
            if protocol == cfg.network.protocol and type(msg) == "table" then
                if msg.kind == "state.get" then
                    network.send(sender, cfg, "state", freshEnvelope(state))
                elseif msg.kind == "ping" then
                    network.send(sender, cfg, "pong", { serverId = os.getComputerID() })
                elseif msg.kind == "command" and type(msg.payload) == "table" then
                    local target = modules[msg.payload.module]
                    if target and type(target.handleCommand) == "function" then
                        local ok, result = pcall(target.handleCommand, msg.payload.action, msg.payload.args, state[msg.payload.module])
                        network.send(sender, cfg, "command.result", { ok = ok, result = result, module = msg.payload.module })
                    else
                        network.send(sender, cfg, "command.result", { ok = false, error = "unsupported module/action" })
                    end
                end
            end

        elseif e[1] == "peripheral" or e[1] == "peripheral_detach" then
            network.openAll()
            modules = loader.discover("modules")
            state = loader.readAll(modules, state)
        end
    end
end

return M
