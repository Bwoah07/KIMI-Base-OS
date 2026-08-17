local M = {}
local network = require("core.network")
local loader = require("core.module_loader")
local updates = require("core.update_service")

local function countTable(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

local function loadProfile(name)
    local ok, profile = pcall(require, "clients." .. tostring(name or "terminal"))
    if ok and type(profile) == "table" then return profile end
    return require("clients.terminal")
end

local function envelope(localState, remoteNodes)
    local combined = {}
    for k, v in pairs(localState or {}) do combined[k] = v end
    combined.nodes = remoteNodes
    return {
        schema = 1,
        serverId = os.getComputerID(),
        version = updates.localVersion(),
        generated = os.epoch("utc"),
        state = combined
    }
end

function M.run(cfg)
    network.host(cfg)
    local modules = loader.discover("modules")
    local state = loader.readAll(modules, {})
    local clients = {}
    local remoteNodes = {}
    local lastModuleScan = os.epoch("utc")

    local profile = nil
    if cfg.localUI then
        profile = loadProfile(cfg.profile)
        if profile.init then profile.init(cfg) end
    end

    local function executeCommand(moduleId, action, args)
        local target = modules[moduleId]
        if target and type(target.handleCommand) == "function" then
            local ok, result = pcall(target.handleCommand, action, args, state[moduleId])
            return { ok = ok, result = result, module = moduleId }
        end
        return { ok = false, error = "unsupported module/action", module = moduleId }
    end

    local function renderLocal()
        if profile and profile.render then
            profile.render(envelope(state, remoteNodes), {
                connected = true,
                lastSeen = os.epoch("utc"),
                serverId = os.getComputerID(),
                localServer = true
            })
        end
    end

    print("KIMI Base Server online - ID " .. os.getComputerID())
    print("Version: " .. updates.localVersion())
    print("Modules: " .. tostring(countTable(modules)))
    if cfg.localUI then print("Local command-center UI: " .. tostring(cfg.profile or "terminal")) end

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
            renderLocal()
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
                    print("[KIMI] notifying " .. tostring(countTable(clients)) .. " known machines...")
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
                    network.send(sender, cfg, "state", envelope(state, remoteNodes))

                elseif msg.kind == "node.state" and type(msg.payload) == "table" then
                    remoteNodes[tostring(sender)] = {
                        nodeId = msg.payload.nodeId or sender,
                        name = msg.payload.name or ("KIMI-NODE-" .. tostring(sender)),
                        version = msg.payload.version,
                        generated = msg.payload.generated,
                        lastSeen = os.epoch("utc"),
                        state = msg.payload.state or {}
                    }

                elseif msg.kind == "ping" then
                    network.send(sender, cfg, "pong", { serverId = os.getComputerID(), version = updates.localVersion() })

                elseif msg.kind == "command" and type(msg.payload) == "table" then
                    network.send(sender, cfg, "command.result", executeCommand(msg.payload.module, msg.payload.action, msg.payload.args))

                elseif msg.kind == "update.status" and type(msg.payload) == "table" then
                    clients[sender].version = msg.payload.version or clients[sender].version
                end
            end

        elseif e[1] == "peripheral" or e[1] == "peripheral_detach" then
            network.openAll()
            modules = loader.discover("modules")
            state = loader.readAll(modules, state)
            if profile and profile.onPeripheralChange then profile.onPeripheralChange() end
            renderLocal()

        elseif profile and profile.handleEvent then
            profile.handleEvent(e, envelope(state, remoteNodes), function(moduleId, action, args)
                return executeCommand(moduleId, action, args)
            end)
        end
    end
end

return M
