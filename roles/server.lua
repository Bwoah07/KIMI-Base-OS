local M = {}
local network = require("core.network")
local loader = require("core.module_loader")
local updates = require("core.update_service")

local function freshEnvelope(state)
    return {
        schema = 1,
        serverId = os.getComputerID(),
        version = updates.localVersion(),
        generated = os.epoch("utc"),
        state = state
    }
end

local function countModules(modules)
    local n = 0
    for _ in pairs(modules) do n = n + 1 end
    return n
end

function M.run(cfg)
    network.host(cfg)
    local modules = loader.discover("modules")
    local state = loader.readAll(modules, {})
    local clients = {}
    local lastModuleScan = os.epoch("utc")

    print("KIMI Base Server online - ID " .. os.getComputerID())
    print("Version: " .. updates.localVersion())
    print("Modules: " .. tostring(countModules(modules)))

    local refreshTimer = os.startTimer(0.5)
    local updateTimer = os.startTimer(updates.interval(cfg))
    local probationTimer = updates.hasPendingProbation() and os.startTimer(15) or nil

    while true do
        local e = { os.pullEvent() }

        if e[1] == "timer" and e[2] == refreshTimer then
            state = loader.readAll(modules, state)
            local now = os.epoch("utc")
            if now - lastModuleScan >= 10000 then
                modules = loader.discover("modules")
                lastModuleScan = now
            end
            refreshTimer = os.startTimer(0.5)

        elseif e[1] == "timer" and e[2] == probationTimer then
            if updates.markHealthy() then print("[KIMI] update probation passed; version marked healthy") end
            probationTimer = nil

        elseif e[1] == "timer" and e[2] == updateTimer then
            if updates.autoEnabled(cfg) then
                local result, err = updates.check()
                if result and result.available then
                    term.setTextColor(colors.yellow)
                    print("[KIMI] fleet update available: " .. result.current .. " -> " .. result.remote)
                    print("[KIMI] notifying " .. tostring(countModules(clients)) .. " known clients...")
                    term.setTextColor(colors.white)

                    for id in pairs(clients) do
                        network.send(id, cfg, "update.available", {
                            version = result.remote,
                            issuedBy = os.getComputerID()
                        })
                    end

                    sleep(1)
                    updates.rebootForUpdate(result.remote, "server-periodic-check")
                elseif not result and err then
                    print("[KIMI] update check skipped: " .. tostring(err))
                end
            end
            updateTimer = os.startTimer(updates.interval(cfg))

        elseif e[1] == "rednet_message" then
            local sender, msg, protocol = e[2], e[3], e[4]
            if protocol == cfg.network.protocol and type(msg) == "table" then
                clients[sender] = clients[sender] or { firstSeen = os.epoch("utc") }
                clients[sender].lastSeen = os.epoch("utc")
                clients[sender].version = type(msg.payload) == "table" and msg.payload.version or clients[sender].version
                clients[sender].profile = type(msg.payload) == "table" and msg.payload.profile or clients[sender].profile

                if msg.kind == "state.get" then
                    network.send(sender, cfg, "state", freshEnvelope(state))
                elseif msg.kind == "ping" then
                    network.send(sender, cfg, "pong", { serverId = os.getComputerID(), version = updates.localVersion() })
                elseif msg.kind == "command" and type(msg.payload) == "table" then
                    local target = modules[msg.payload.module]
                    if target and type(target.handleCommand) == "function" then
                        local ok, result = pcall(target.handleCommand, msg.payload.action, msg.payload.args, state[msg.payload.module])
                        network.send(sender, cfg, "command.result", { ok = ok, result = result, module = msg.payload.module })
                    else
                        network.send(sender, cfg, "command.result", { ok = false, error = "unsupported module/action" })
                    end
                elseif msg.kind == "update.status" and type(msg.payload) == "table" then
                    clients[sender].version = msg.payload.version or clients[sender].version
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
