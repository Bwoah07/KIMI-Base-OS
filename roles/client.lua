local M = {}
local network = require("core.network")
local loader = require("core.module_loader")
local updates = require("core.update_service")

local function loadProfile(name)
    local ok, profile = pcall(require, "clients." .. tostring(name or "terminal"))
    if ok and type(profile) == "table" then return profile end
    return require("clients.terminal")
end

local function discoverModules()
    return loader.discover("modules")
end

function M.run(cfg)
    network.openAll()
    local profile = loadProfile(cfg.profile)
    local modules = discoverModules()
    local localState = loader.readAll(modules, {})
    local serverId, state, lastSeen = nil, nil, 0
    local lastModuleScan = os.epoch("utc")
    if profile.init then profile.init(cfg) end

    local pollTimer = os.startTimer(0.1)
    local probationTimer = updates.hasPendingProbation() and os.startTimer(15) or nil

    while true do
        local e = { os.pullEvent() }

        if e[1] == "timer" and e[2] == pollTimer then
            if not serverId then serverId = network.findServer(cfg) end

            local now = os.epoch("utc")
            if now - lastModuleScan >= 10000 then
                modules = discoverModules()
                lastModuleScan = now
            end
            localState = loader.readAll(modules, localState)

            if serverId then
                network.send(serverId, cfg, "state.get", {
                    clientId = os.getComputerID(),
                    role = "client",
                    name = cfg.name,
                    profile = cfg.profile,
                    version = updates.localVersion()
                })

                -- Every client is also a telemetry source. If it has no useful
                -- peripherals the module state is simply empty/offline; if it has
                -- sensors, that data becomes available to the entire KIMI fleet.
                network.send(serverId, cfg, "telemetry.state", {
                    sourceId = os.getComputerID(),
                    role = "client",
                    name = cfg.name,
                    profile = cfg.profile,
                    version = updates.localVersion(),
                    generated = now,
                    state = localState
                })
            end

            if profile.render then
                profile.render(state, {
                    connected = serverId ~= nil,
                    lastSeen = lastSeen,
                    serverId = serverId,
                    localState = localState
                })
            end
            pollTimer = os.startTimer(1)

        elseif e[1] == "timer" and e[2] == probationTimer then
            if updates.markHealthy() then print("[KIMI] update probation passed; version marked healthy") end
            probationTimer = nil

        elseif e[1] == "rednet_message" then
            local sender, msg, protocol = e[2], e[3], e[4]
            if protocol == cfg.network.protocol and type(msg) == "table" then
                if sender == serverId and msg.kind == "state" then
                    state = msg.payload
                    lastSeen = os.epoch("utc")
                    if profile.onState then profile.onState(state) end
                    if profile.render then
                        profile.render(state, {
                            connected = true,
                            lastSeen = lastSeen,
                            serverId = serverId,
                            localState = localState
                        })
                    end

                elseif sender == serverId and msg.kind == "update.available" and type(msg.payload) == "table" then
                    local target = tostring(msg.payload.version or "")
                    if updates.autoEnabled(cfg) and target ~= "" and target ~= updates.localVersion() then
                        network.send(serverId, cfg, "update.status", {
                            role = "client",
                            version = updates.localVersion(),
                            target = target,
                            status = "accepted"
                        })
                        sleep((os.getComputerID() % 4) + 1)
                        updates.rebootForUpdate(target, "server-announcement")
                    end
                end
            end

        elseif e[1] == "peripheral" or e[1] == "peripheral_detach" then
            network.openAll()
            serverId = network.findServer(cfg)
            modules = discoverModules()
            localState = loader.readAll(modules, localState)
            if profile.onPeripheralChange then profile.onPeripheralChange() end

        else
            if profile.handleEvent then
                profile.handleEvent(e, state, function(module, action, args)
                    if serverId then
                        network.send(serverId, cfg, "command", { module = module, action = action, args = args })
                    end
                end)
            end
        end
    end
end

return M
