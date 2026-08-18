-- KIMI Base OS bridge for cc-mek-scada
-- Keeps upstream cc-mek-scada code/UI intact while reporting status to KIMI.

local KIMI_PROTOCOL = "kimi_base_os_v1"
local KIMI_HOST = "kimi-base"
local KIMI_OWNER = "Bwoah07"
local KIMI_REPO = "KIMI-Base-OS"
local KIMI_BRANCH = "main"
local SELF_REPO_PATH = "scada/kimi_scada_boot.lua"

local SCADA_MANIFEST = "https://mikaylafischler.github.io/cc-mek-scada/manifests/main/install_manifest.json"
local SCADA_BUILD = "https://mikaylafischler.github.io/cc-mek-scada/builds/main/"

local ROOT = "/.kimi-scada"
local STAGE = ROOT .. "/staging"
local BACKUP = ROOT .. "/rollback"
local REQUESTED = ROOT .. "/update_requested"
local LAST_RESULT = ROOT .. "/last_result"
local LOCAL_MANIFEST = "/install_manifest.json"
local TELEMETRY_INTERVAL = 5
local UPSTREAM_CHECK_INTERVAL = 600

local APPS = { "reactor-plc", "rtu", "supervisor", "coordinator", "pocket" }

local function ensureParent(path)
    local dir = fs.getDir(path)
    if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
end

local function writeFile(path, data)
    ensureParent(path)
    local f = assert(fs.open(path, "w"))
    f.write(data)
    f.close()
end

local function readFile(path)
    if not fs.exists(path) or fs.isDir(path) then return nil end
    local f = fs.open(path, "r")
    if not f then return nil end
    local data = f.readAll()
    f.close()
    return data
end

local function readJSON(path)
    local raw = readFile(path)
    if not raw then return nil end
    local ok, value = pcall(textutils.unserializeJSON, raw)
    if ok and type(value) == "table" then return value end
    return nil
end

local function httpJSON(url, headers)
    local r, err = http.get(url, headers)
    if not r then return nil, err end
    local body = r.readAll()
    r.close()
    local ok, obj = pcall(textutils.unserializeJSON, body)
    if not ok or type(obj) ~= "table" then return nil, "invalid JSON" end
    return obj
end

local function detectApp()
    for _, app in ipairs(APPS) do
        if fs.exists("/" .. app .. "/startup.lua") then return app end
    end
    return nil
end

local function openModems()
    local count = 0
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "modem") then
            if pcall(rednet.open, name) then count = count + 1 end
        end
    end
    return count
end

local function methodSet(name)
    local set = {}
    local ok, methods = pcall(peripheral.getMethods, name)
    if ok and type(methods) == "table" then
        for _, m in ipairs(methods) do set[m] = true end
    end
    return set
end

local function reactorStatus()
    for _, name in ipairs(peripheral.getNames()) do
        local methods = methodSet(name)
        if methods.getStatus and methods.scram then
            local ok, active = pcall(peripheral.call, name, "getStatus")
            if ok then return active == true, name end
        end
    end
    return false, nil
end

local function scramAll()
    local count = 0
    for _, name in ipairs(peripheral.getNames()) do
        local methods = methodSet(name)
        if methods.scram then
            local ok = pcall(peripheral.call, name, "scram")
            if ok then count = count + 1 end
        end
    end
    return count
end

local function fetchUpstream()
    local cb = tostring(os.epoch("utc"))
    return httpJSON(SCADA_MANIFEST .. "?kimi_cb=" .. textutils.urlEncode(cb))
end

local function appVersion(manifest, app)
    return manifest and manifest.versions and manifest.versions[app] or nil
end

local function copyFile(src, dst)
    ensureParent(dst)
    if fs.exists(dst) then fs.delete(dst) end
    fs.copy(src, dst)
end

local function clearDir(path)
    if fs.exists(path) then fs.delete(path) end
    fs.makeDir(path)
end

local function fetchText(url)
    local r, err = http.get(url)
    if not r then return nil, err end
    local body = r.readAll()
    r.close()
    if not body or body == "" then return nil, "empty response" end
    return body
end

local function validateLua(path, body)
    if path:sub(-4) ~= ".lua" then return true end
    local fn, err = load(body, "@" .. path)
    if not fn then return false, err end
    return true
end

local function packageList(manifest, app)
    local out = {}
    for _, dep in ipairs((manifest.depends and manifest.depends[app]) or {}) do out[#out + 1] = dep end
    out[#out + 1] = app
    return out
end

local function pathSet(manifest, packages)
    local set, list = {}, {}
    if type(manifest) ~= "table" or type(manifest.files) ~= "table" then return set, list end
    for _, pkg in ipairs(packages or {}) do
        for _, path in ipairs(manifest.files[pkg] or {}) do
            if not set[path] then
                set[path] = true
                list[#list + 1] = path
            end
        end
    end
    table.sort(list)
    return set, list
end

local function filteredManifest(remote, app, packages)
    local copy = textutils.unserialize(textutils.serialize(remote))
    local keep = { installer = true, comms = true }
    for _, pkg in ipairs(packages) do
        if pkg == "system" then keep.bootloader = true else keep[pkg] = true end
    end
    keep[app] = true

    local versions = {}
    for key, value in pairs(copy.versions or {}) do
        if keep[key] then versions[key] = value end
    end
    copy.versions = versions
    return copy
end

local function restoreSelf()
    local api = "https://api.github.com/repos/" .. KIMI_OWNER .. "/" .. KIMI_REPO .. "/commits/" .. KIMI_BRANCH
    local headers = { ["User-Agent"] = "KIMI-SCADA-Bridge", ["Accept"] = "application/vnd.github+json" }
    local head, err = httpJSON(api .. "?kimi_cb=" .. tostring(os.epoch("utc")), headers)
    if not head or type(head.sha) ~= "string" then return false, err or "invalid KIMI head" end

    local raw = "https://raw.githubusercontent.com/" .. KIMI_OWNER .. "/" .. KIMI_REPO .. "/" .. head.sha .. "/" .. SELF_REPO_PATH
    local body, fetchErr = fetchText(raw .. "?kimi_cb=" .. tostring(os.epoch("utc")))
    if not body then return false, fetchErr end
    local ok, syntaxErr = validateLua("startup.lua", body)
    if not ok then return false, syntaxErr end
    writeFile("/startup.lua", body)
    return true
end

local function rollback()
    local state = readJSON(BACKUP .. "/state.json")
    if not state or type(state.files) ~= "table" then return false end

    for _, item in ipairs(state.files) do
        local target = "/" .. item.path
        if fs.exists(target) then fs.delete(target) end
        if item.existed then
            local src = BACKUP .. "/files/" .. item.path
            if fs.exists(src) then copyFile(src, target) end
        end
    end

    if state.manifestExisted and fs.exists(BACKUP .. "/install_manifest.json") then
        copyFile(BACKUP .. "/install_manifest.json", LOCAL_MANIFEST)
    elseif fs.exists(LOCAL_MANIFEST) then
        fs.delete(LOCAL_MANIFEST)
    end

    restoreSelf()
    return true
end

local function applyUpstreamUpdate(app)
    local remote, err = fetchUpstream()
    if not remote then return false, "upstream manifest: " .. tostring(err) end
    if not (remote.files and remote.depends and remote.versions) then return false, "invalid upstream manifest" end

    local packages = packageList(remote, app)
    local newSet, newPaths = pathSet(remote, packages)
    local oldManifest = readJSON(LOCAL_MANIFEST)
    local _, oldPaths = pathSet(oldManifest or {}, packages)

    clearDir(STAGE)
    for _, path in ipairs(newPaths) do
        local body, dlErr = fetchText(SCADA_BUILD .. path .. "?kimi_cb=" .. tostring(os.epoch("utc")))
        if not body then fs.delete(STAGE); return false, "download " .. path .. ": " .. tostring(dlErr) end
        local valid, syntaxErr = validateLua(path, body)
        if not valid then fs.delete(STAGE); return false, "invalid " .. path .. ": " .. tostring(syntaxErr) end
        writeFile(STAGE .. "/" .. path, body)
    end

    local affected, affectedList = {}, {}
    local function add(path)
        if not affected[path] then affected[path] = true; affectedList[#affectedList + 1] = path end
    end
    for _, path in ipairs(oldPaths) do add(path) end
    for _, path in ipairs(newPaths) do add(path) end

    clearDir(BACKUP)
    fs.makeDir(BACKUP .. "/files")
    local backupState = { files = {}, manifestExisted = fs.exists(LOCAL_MANIFEST) }
    for _, path in ipairs(affectedList) do
        local target = "/" .. path
        local existed = fs.exists(target) and not fs.isDir(target)
        backupState.files[#backupState.files + 1] = { path = path, existed = existed }
        if existed then copyFile(target, BACKUP .. "/files/" .. path) end
    end
    if backupState.manifestExisted then copyFile(LOCAL_MANIFEST, BACKUP .. "/install_manifest.json") end
    writeFile(BACKUP .. "/state.json", textutils.serializeJSON(backupState))

    local ok, installErr = pcall(function()
        for _, path in ipairs(oldPaths) do
            if not newSet[path] and path ~= "startup.lua" then
                local target = "/" .. path
                if fs.exists(target) and not fs.isDir(target) then fs.delete(target) end
            end
        end
        for _, path in ipairs(newPaths) do
            local staged = STAGE .. "/" .. path
            local target = "/" .. path
            ensureParent(target)
            if fs.exists(target) then fs.delete(target) end
            fs.copy(staged, target)
        end
        writeFile(LOCAL_MANIFEST, textutils.serializeJSON(filteredManifest(remote, app, packages)))
        local restored, restoreErr = restoreSelf()
        if not restored then error("failed to restore KIMI bridge: " .. tostring(restoreErr)) end
    end)

    fs.delete(STAGE)
    if not ok then
        rollback()
        return false, tostring(installErr)
    end

    return true, appVersion(remote, app)
end

local app = detectApp()
if not app then
    term.setTextColor(colors.red)
    print("KIMI SCADA bridge: no cc-mek-scada application found")
    term.setTextColor(colors.white)
    return
end

if not fs.exists(ROOT) then fs.makeDir(ROOT) end

if fs.exists(REQUESTED) then
    print("[KIMI SCADA] applying staged upstream update for " .. app .. "...")
    local ok, result = applyUpstreamUpdate(app)
    if ok then
        writeFile(LAST_RESULT, "updated to " .. tostring(result) .. " at " .. tostring(os.epoch("utc")))
        fs.delete(REQUESTED)
        print("[KIMI SCADA] update complete")
    else
        writeFile(LAST_RESULT, "update failed: " .. tostring(result))
        fs.delete(REQUESTED)
        term.setTextColor(colors.red)
        print("[KIMI SCADA] update failed: " .. tostring(result))
        term.setTextColor(colors.white)
    end
end

local latestRemote = nil
local latestError = nil
local lastCheck = 0

local function checkRemote(force)
    local now = os.epoch("utc")
    if not force and latestRemote and (now - lastCheck) < UPSTREAM_CHECK_INTERVAL * 1000 then return end
    lastCheck = now
    local remote, err = fetchUpstream()
    latestRemote = remote
    latestError = err
end

local function telemetryState()
    local localManifest = readJSON(LOCAL_MANIFEST) or {}
    local localVer = appVersion(localManifest, app)
    local remoteVer = appVersion(latestRemote, app)
    local active, reactorPeripheral = reactorStatus()
    local id = "scada_" .. app:gsub("%-", "_")

    return {
        [id] = {
            _status = "online",
            _updated = os.epoch("utc"),
            app = app,
            installedVersion = localVer or "unknown",
            upstreamVersion = remoteVer or "unknown",
            updateAvailable = localVer ~= nil and remoteVer ~= nil and localVer ~= remoteVer,
            upstreamStatus = latestRemote and "online" or "error",
            upstreamError = latestError,
            lastCheck = lastCheck,
            reactorActive = active,
            reactorPeripheral = reactorPeripheral,
            bridge = "KIMI SCADA Bridge v1"
        }
    }
end

local function sendTelemetry(serverId)
    if not serverId then return false end
    local state = telemetryState()
    local payload = {
        sourceId = os.getComputerID(),
        role = "scada",
        name = "SCADA-" .. app,
        profile = app,
        version = appVersion(readJSON(LOCAL_MANIFEST) or {}, app) or "unknown",
        generated = os.epoch("utc"),
        state = state
    }
    return rednet.send(serverId, { kind = "telemetry.state", payload = payload, sent = os.epoch("utc") }, KIMI_PROTOCOL)
end

local function agent()
    openModems()
    checkRemote(true)
    local serverId = rednet.lookup(KIMI_PROTOCOL, KIMI_HOST)
    local telemetryTimer = os.startTimer(0.2)
    local upstreamTimer = os.startTimer(UPSTREAM_CHECK_INTERVAL)

    while true do
        local e = { os.pullEvent() }
        if e[1] == "timer" and e[2] == telemetryTimer then
            if not serverId then serverId = rednet.lookup(KIMI_PROTOCOL, KIMI_HOST) end
            sendTelemetry(serverId)
            telemetryTimer = os.startTimer(TELEMETRY_INTERVAL)
        elseif e[1] == "timer" and e[2] == upstreamTimer then
            checkRemote(true)
            upstreamTimer = os.startTimer(UPSTREAM_CHECK_INTERVAL)
        elseif e[1] == "rednet_message" then
            local sender, msg, protocol = e[2], e[3], e[4]
            if protocol == KIMI_PROTOCOL and sender == serverId and type(msg) == "table" and msg.kind == "scada.update.request" then
                local state = telemetryState()
                local module = state["scada_" .. app:gsub("%-", "_")]
                if module and module.updateAvailable then
                    local scrammed = scramAll()
                    writeFile(REQUESTED, textutils.serialize({ requested = os.epoch("utc"), by = sender, app = app, scrammed = scrammed }))
                    sendTelemetry(serverId)
                    sleep(0.5)
                    os.reboot()
                end
            elseif protocol == KIMI_PROTOCOL and type(msg) == "table" and msg.kind == "pong" then
                serverId = sender
            end
        elseif e[1] == "peripheral" or e[1] == "peripheral_detach" then
            openModems()
            serverId = rednet.lookup(KIMI_PROTOCOL, KIMI_HOST)
        end
    end
end

local function runScada()
    print("[KIMI SCADA] launching upstream " .. app .. "...")
    return shell.run(app .. "/startup")
end

parallel.waitForAny(runScada, agent)
