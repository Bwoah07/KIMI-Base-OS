local M = {}
local network = require("core.network")
local updates = require("core.update_service")

local function loadProfile(name)
    local ok, profile = pcall(require, "clients." .. tostring(name or "terminal"))
    if ok and type(profile) == "table" then return profile end
    return require("clients.terminal")
end

function M.run(cfg)
    network.openAll()
    local profile = loadProfile(cfg.profile)
    local serverId, state, lastSeen = nil, nil, 0
    if profile.init then profile.init(cfg) end

    local pollTimer = os.startTimer(0.1)
    local updateTimer = os.startTimer(updates.interval(cfg))
    local probationTimer = updates.hasPendingProbation() and os.startTimer(15) or nil

    while true do
        local e = { os.pullEvent() }

        if e[1] == "timer" and e[2] == pollTimer then
            if not serverId then serverId = network.findServer(cfg) end
            if serverId then
                network.send(serverId, cfg, "state.get", {
                    clientId = os.getComputerID(),
                    profile = cfg.profile,
                    version = updates.localVersion()
                })
            end
            if profile.render then profile.render(state, { connected = serverId ~= nil, lastSeen = lastSeen, serverId = serverId }) end
            pollTimer = os.startTimer(1)

        elseif e[1] == "timer" and e[2] == probationTimer then
            if updates.markHealthy() then print("[KIMI] update probation passed; version marked healthy") end
            probationTimer = nil

        elseif e[1] == "timer" and e[2] == updateTimer then
            -- Independent fallback: a client that missed the server broadcast still
            -- catches up even if it stays online for days.
            if updates.autoEnabled(cfg) then
                local result = updates.check()
                if result and result.available then
                    updates.rebootForUpdate(result.remote, "client-periodic-fallback")
                end
            end
            updateTimer = os.startTimer(updates.interval(cfg))

        elseif e[1] == "rednet_message" then
            local sender, msg, protocol = e[2], e[3], e[4]
            if protocol == cfg.network.protocol and type(msg) == "table" then
                if sender == serverId and msg.kind == "state" then
                    state = msg.payload
                    lastSeen = os.epoch("utc")
                    if profile.onState then profile.onState(state) end
                    if profile.render then profile.render(state, { connected = true, lastSeen = lastSeen, serverId = serverId }) end

                elseif sender == serverId and msg.kind == "update.available" and type(msg.payload) == "table" then
                    local target = tostring(msg.payload.version or "")
                    if updates.autoEnabled(cfg) and target ~= "" and target ~= updates.localVersion() then
                        network.send(serverId, cfg, "update.status", {
                            version = updates.localVersion(),
                            target = target,
                            status = "accepted"
                        })
                        -- Small deterministic stagger so a large fleet does not all
                        -- hammer GitHub in the exact same tick.
                        sleep((os.getComputerID() % 4) + 1)
                        updates.rebootForUpdate(target, "server-announcement")
                    end
                end
            end

        elseif e[1] == "peripheral" or e[1] == "peripheral_detach" then
            network.openAll()
            serverId = network.findServer(cfg)
            if profile.onPeripheralChange then profile.onPeripheralChange() end

        else
            if profile.handleEvent then profile.handleEvent(e, state, function(module, action, args)
                if serverId then network.send(serverId, cfg, "command", { module = module, action = action, args = args }) end
            end) end
        end
    end
end

return M
