local M = {}
local network = require("core.network")
local loader = require("core.module_loader")
local updates = require("core.update_service")

local function countTable(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

function M.run(cfg)
    network.openAll()
    local modules = loader.discover("modules")
    local state = loader.readAll(modules, {})
    local serverId = nil
    local lastModuleScan = os.epoch("utc")
    local publishInterval = tonumber(cfg.node and cfg.node.publishInterval) or 2
    publishInterval = math.max(0.5, publishInterval)

    print("KIMI Remote Node online - ID " .. os.getComputerID())
    print("Version: " .. updates.localVersion())
    print("Modules: " .. tostring(countTable(modules)))

    local timer = os.startTimer(0.1)
    while true do
        local e = { os.pullEvent() }

        if e[1] == "timer" and e[2] == timer then
            if not serverId then serverId = network.findServer(cfg) end
            state = loader.readAll(modules, state)

            local now = os.epoch("utc")
            if now - lastModuleScan >= 10000 then
                modules = loader.discover("modules")
                lastModuleScan = now
            end

            if serverId then
                network.send(serverId, cfg, "node.state", {
                    nodeId = os.getComputerID(),
                    name = cfg.name,
                    version = updates.localVersion(),
                    profile = "node",
                    generated = now,
                    state = state
                })
            end
            timer = os.startTimer(publishInterval)

        elseif e[1] == "rednet_message" then
            local sender, msg, protocol = e[2], e[3], e[4]
            if protocol == cfg.network.protocol and type(msg) == "table" then
                if not serverId then serverId = network.findServer(cfg) end
                if sender == serverId and msg.kind == "update.available" and type(msg.payload) == "table" then
                    local target = tostring(msg.payload.version or "")
                    if updates.autoEnabled(cfg) and target ~= "" and target ~= updates.localVersion() then
                        network.send(serverId, cfg, "update.status", {
                            version = updates.localVersion(),
                            target = target,
                            status = "accepted"
                        })
                        sleep((os.getComputerID() % 4) + 1)
                        updates.rebootForUpdate(target, "server-announcement")
                    end
                elseif sender == serverId and msg.kind == "ping" then
                    network.send(serverId, cfg, "pong", {
                        nodeId = os.getComputerID(),
                        version = updates.localVersion()
                    })
                end
            end

        elseif e[1] == "peripheral" or e[1] == "peripheral_detach" then
            network.openAll()
            serverId = network.findServer(cfg)
            modules = loader.discover("modules")
            state = loader.readAll(modules, state)
        end
    end
end

return M
