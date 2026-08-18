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
    local ok, profile = pcall(require, "clients." .. tostring(name or "admin"))
    if ok and type(profile) == "table" then return profile end
    return require("clients.terminal")
end

local function copyTable(src)
    local out = {}
    for k, v in pairs(src or {}) do out[k] = v end
    return out
end

local function versionRank(v)
    local major, minor, patch, alpha = tostring(v or ""):match("^(%d+)%.(%d+)%.(%d+)%-alpha%.(%d+)$")
    if not major then return nil end
    return tonumber(major) * 1000000000 + tonumber(minor) * 1000000 + tonumber(patch) * 1000 + tonumber(alpha)
end

local function canonicalState(localState, sources, machines, updateInfo)
    local combined = copyTable(localState)
    local selected = {}
    for sourceId, source in pairs(sources or {}) do
        for moduleId, value in pairs(source.state or {}) do
            if type(value) == "table" then
                local stamp = tonumber(value._updated) or tonumber(source.generated) or 0
                local prev = selected[moduleId]
                if not prev or stamp > prev.stamp then selected[moduleId] = { stamp = stamp, value = value, sourceId = sourceId } end
            end
        end
    end
    for moduleId, picked in pairs(selected) do
        local localStamp = type(combined[moduleId]) == "table" and tonumber(combined[moduleId]._updated) or 0
        if not combined[moduleId] or picked.stamp > localStamp then
            combined[moduleId] = picked.value
            combined[moduleId]._source = picked.sourceId
        end
    end
    combined.sources = sources
    combined.fleet = machines
    combined.update = updateInfo
    return combined
end

local function makeEnvelope(localState, sources, machines, updateInfo)
    return { schema = 2, serverId = os.getComputerID(), version = updates.localVersion(), generated = os.epoch("utc"), state = canonicalState(localState, sources, machines, updateInfo) }
end

function M.run(cfg)
    network.host(cfg)
    local modules = loader.discover("modules")
    local state = loader.readAll(modules, {})
    local machines, sources = {}, {}
    local lastModuleScan = os.epoch("utc")
    local startedAt = os.epoch("utc")
    local updateInfo = { authority = os.getComputerID(), lastCheck = nil, lastResult = "not checked", remoteVersion = nil, targetVersion = nil }

    local profile = nil
    if cfg.localUI then
        profile = loadProfile("admin")
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

    local function env() return makeEnvelope(state, sources, machines, updateInfo) end

    local function renderLocal()
        if profile and profile.render then
            profile.render(env(), { connected = true, lastSeen = os.epoch("utc"), serverId = os.getComputerID(), localServer = true, startedAt = startedAt, machines = machines, sources = sources, update = updateInfo })
        end
    end

    local function offerCatchup(sender, machine)
        local serverVersion = updates.localVersion()
        local sr, mr = versionRank(serverVersion), versionRank(machine and machine.version)
        if sr and mr and mr < sr then
            network.send(sender, cfg, "update.available", { version = serverVersion, issuedBy = os.getComputerID(), reason = "fleet-catchup" })
        end
    end

    local function touchMachine(sender, payload, defaultRole)
        local now = os.epoch("utc")
        local m = machines[sender] or { firstSeen = now }
        m.lastSeen = now
        m.role = payload and payload.role or m.role or defaultRole or "client"
        m.name = payload and payload.name or m.name or ("KIMI-" .. tostring(sender))
        m.profile = payload and payload.profile or m.profile
        m.version = payload and payload.version or m.version
        machines[sender] = m
        offerCatchup(sender, m)
        return m
    end

    local function checkForUpdates(reason)
        if not updates.autoEnabled(cfg) then
            updateInfo.lastCheck = os.epoch("utc")
            updateInfo.lastResult = "updates disabled"
            renderLocal()
            return false
        end

        updateInfo.lastCheck = os.epoch("utc")
        updateInfo.lastResult = "checking..."
        renderLocal()

        local result, err = updates.check()
        if not result then
            updateInfo.lastResult = "check failed: " .. tostring(err)
            renderLocal()
            print("[KIMI] update check skipped: " .. tostring(err))
            return false
        end

        updateInfo.remoteVersion = result.remote
        updateInfo.lastResult = result.available and "update available" or "up to date"
        updateInfo.targetVersion = result.available and result.remote or nil
        renderLocal()

        if not result.available then
            print("[KIMI] manual/periodic update check: up to date " .. tostring(result.current))
            return false
        end

        term.setTextColor(colors.yellow)
        print("[KIMI] fleet update available: " .. result.current .. " -> " .. result.remote)
        print("[KIMI] notifying " .. tostring(countTable(machines)) .. " connected/known machines...")
        term.setTextColor(colors.white)

        for id, machine in pairs(machines) do
            if machine.online ~= false then
                network.send(id, cfg, "update.available", {
                    version = result.remote,
                    issuedBy = os.getComputerID(),
                    reason = reason or "server-check"
                })
            end
        end

        sleep(2)
        updates.rebootForUpdate(result.remote, reason or "server-check")
        return true
    end

    print("KIMI Base Server online - ID " .. os.getComputerID())
    print("Version: " .. updates.localVersion())
    print("Modules: " .. tostring(countTable(modules)))
    if cfg.localUI then print("Command-center admin UI: enabled") end

    local refreshTimer = os.startTimer(0.5)
    local updateTimer = os.startTimer(updates.interval(cfg))
    local probationTimer = updates.hasPendingProbation() and os.startTimer(15) or nil

    while true do
        local e = { os.pullEvent() }
        if e[1] == "timer" and e[2] == refreshTimer then
            state = loader.readAll(modules, state)
            local now = os.epoch("utc")
            if now - lastModuleScan >= 10000 then modules = loader.discover("modules"); lastModuleScan = now end
            for _, m in pairs(machines) do m.online = (now - (tonumber(m.lastSeen) or 0)) <= 15000 end
            for _, s in pairs(sources) do s.online = (now - (tonumber(s.lastSeen) or 0)) <= 15000 end
            renderLocal()
            refreshTimer = os.startTimer(0.5)

        elseif e[1] == "timer" and e[2] == probationTimer then
            if updates.markHealthy() then print("[KIMI] update probation passed; version marked healthy") end
            probationTimer = nil

        elseif e[1] == "timer" and e[2] == updateTimer then
            checkForUpdates("server-periodic-check")
            updateTimer = os.startTimer(updates.interval(cfg))

        elseif e[1] == "rednet_message" then
            local sender, msg, protocol = e[2], e[3], e[4]
            if protocol == cfg.network.protocol and type(msg) == "table" then
                local payload = type(msg.payload) == "table" and msg.payload or {}
                if msg.kind == "state.get" then
                    touchMachine(sender, payload, "client")
                    network.send(sender, cfg, "state", env())
                elseif msg.kind == "telemetry.state" or msg.kind == "node.state" then
                    local m = touchMachine(sender, payload, msg.kind == "node.state" and "node" or "client")
                    sources[tostring(sender)] = { sourceId = payload.sourceId or payload.nodeId or sender, role = payload.role or m.role, name = payload.name or m.name, profile = payload.profile or m.profile, version = payload.version or m.version, generated = payload.generated, lastSeen = os.epoch("utc"), online = true, state = payload.state or {} }
                elseif msg.kind == "ping" then
                    touchMachine(sender, payload, payload.role or "client")
                    network.send(sender, cfg, "pong", { serverId = os.getComputerID(), version = updates.localVersion() })
                elseif msg.kind == "command" then
                    touchMachine(sender, payload, "client")
                    network.send(sender, cfg, "command.result", executeCommand(payload.module, payload.action, payload.args))
                elseif msg.kind == "update.status" then
                    local m = touchMachine(sender, payload, payload.role or "client")
                    m.version = payload.version or m.version
                    m.updateTarget = payload.target
                    m.updateStatus = payload.status
                end
            end

        elseif e[1] == "peripheral" or e[1] == "peripheral_detach" then
            network.openAll()
            modules = loader.discover("modules")
            state = loader.readAll(modules, state)
            if profile and profile.onPeripheralChange then profile.onPeripheralChange() end
            renderLocal()

        elseif profile and profile.handleEvent then
            profile.handleEvent(e, env(), function(moduleId, action, args)
                if moduleId == "server" and action == "check_updates" then
                    return checkForUpdates("server-manual-check")
                end
                return executeCommand(moduleId, action, args)
            end)
        end
    end
end

return M
