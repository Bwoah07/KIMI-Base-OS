local M = {}
local network = require("core.network")
local loader = require("core.module_loader")
local updates = require("core.update_service")

local function countTable(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

local function hasUnhealthyState(state)
    for _, value in pairs(state or {}) do
        if type(value) == "table" then
            local s = tostring(value._status or value.status or ""):lower()
            if s == "offline" or s == "error" or s == "disconnected" then return true end
        end
    end
    return false
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
    local probationTimer = updates.hasPendingProbation() and os.startTimer(15) or nil

    while true do
        local e = { os.pullEvent() }

        if e[1] == "timer" and e[2] == timer then
            if not serverId then serverId = network.findServer(cfg) end
            state = loader.readAll(modules, state)

            local now = os.epoch("utc")
            -- A Mekanism multiblock can temporarily invalidate its peripheral without
            -- producing a useful attach/detach event. While anything is unhealthy,
            -- actively re-open the network and rediscover modules every publish cycle.
            if hasUnhealthyState(state) or now - lastModuleScan >= 10000 then
                network.openAll()
                modules = loader.discover("modules")
                state = loader.readAll(modules, state)
                lastModuleScan = now
            end

            if serverId then
                network.send(serverId, cfg, "telemetry.state", {
                    sourceId = os.getComputerID(),
                    role = "node",
                    name = cfg.name,
                    profile = "node",
                    version = updates.localVersion(),
                    generated = now,
                    state = state
                })
            end
            timer = os.startTimer(publishInterval)

        elseif e[1] == "timer" and e[2] == probationTimer then
            if updates.markHealthy() then print("[KIMI] update probation passed; version marked healthy") end
            probationTimer = nil

        elseif e[1] == "rednet_message" then
            local sender, msg, protocol = e[2], e[3], e[4]
            if protocol == cfg.network.protocol and type(msg) == "table" then
                if not serverId then serverId = network.findServer(cfg) end
                if sender == serverId and msg.kind == "update.available" and type(msg.payload) == "table" then
                    local target = tostring(msg.payload.version or "")
                    if updates.autoEnabled(cfg) and target ~= "" and target ~= updates.localVersion() then
                        network.send(serverId, cfg, "update.status", {
                            role = "node",
                            version = updates.localVersion(),
                            target = target,
                            status = "accepted"
                        })
                        sleep((os.getComputerID() % 4) + 1)
                        updates.rebootForUpdate(target, "server-announcement")
                    end
                elseif sender == serverId and msg.kind == "ping" then
                    network.send(serverId, cfg, "pong", {
                        role = "node",
                        nodeId = os.getComputerID(),
                        version = updates.localVersion()
                    })
                elseif sender == serverId and msg.kind == "module.command" and type(msg.payload) == "table" then
                    local payload = msg.payload
                    local target = modules[payload.module]
                    local ok, result
                    if target and type(target.handleCommand) == "function" then
                        ok, result = pcall(target.handleCommand, payload.action, payload.args, state[payload.module])
                    else
                        ok, result = false, "unsupported module/action"
                    end
                    state = loader.readAll(modules, state)
                    network.send(serverId, cfg, "module.command.result", {
                        ok = ok,
                        result = result,
                        module = payload.module,
                        action = payload.action,
                        sourceId = os.getComputerID()
                    })
                end
            end

        elseif e[1] == "peripheral" or e[1] == "peripheral_detach" then
            network.openAll()
            serverId = network.findServer(cfg)
            modules = loader.discover("modules")
            state = loader.readAll(modules, state)
            lastModuleScan = os.epoch("utc")
        end
    end
end

return M
