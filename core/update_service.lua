local M = {}

local ROOT = ".kimi"
local PENDING = ROOT .. "/update_pending"
local REQUESTED = ROOT .. "/update_requested"
local INSTALLED_MANIFEST = ROOT .. "/installed_manifest.json"
local ROLLBACK = ROOT .. "/rollback"
local STAGING = ROOT .. "/staging"
local RELOAD = ROOT .. "/reload_requested"
M.RELOAD_SENTINEL = "__KIMI_LIVE_RELOAD__"
local OWNER, REPO, BRANCH = "Bwoah07", "KIMI-Base-OS", "main"
local API_HEAD = "https://api.github.com/repos/" .. OWNER .. "/" .. REPO .. "/commits/" .. BRANCH
local RAW_ROOT = "https://raw.githubusercontent.com/" .. OWNER .. "/" .. REPO .. "/"

local function readFile(path)
    if not fs.exists(path) or fs.isDir(path) then return nil end
    local f = fs.open(path, "r")
    if not f then return nil end
    local data = f.readAll(); f.close(); return data
end

local function writeFile(path, data)
    local dir = fs.getDir(path)
    if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
    local f = assert(fs.open(path, "w")); f.write(data); f.close()
end

local function nonce()
    return tostring(os.epoch("utc")) .. "-" .. tostring(math.random(100000,999999))
end

local function getHeadSha()
    local url = API_HEAD .. "?kimi_cb=" .. textutils.urlEncode(nonce())
    local headers = { ["User-Agent"] = "KIMI-Base-OS", ["Accept"] = "application/vnd.github+json" }
    local r, err = http.get(url, headers)
    if not r then return nil, err end
    local body = r.readAll(); r.close()
    local obj = body and textutils.unserializeJSON(body) or nil
    if type(obj) ~= "table" or type(obj.sha) ~= "string" or obj.sha == "" then
        return nil, "invalid GitHub head response"
    end
    return obj.sha
end

local function fetchRaw(ref, path)
    local url = RAW_ROOT .. tostring(ref) .. "/" .. path .. "?kimi_cb=" .. textutils.urlEncode(nonce())
    local r, err = http.get(url)
    if not r then return nil, err end
    local body = r.readAll(); r.close()
    if not body or body == "" then return nil, "empty response for " .. path end
    return body
end

function M.localVersion()
    return ((readFile("version.txt") or "not-installed"):gsub("%s+$", ""))
end

function M.localManifest()
    local raw = readFile(INSTALLED_MANIFEST)
    local manifest = raw and textutils.unserializeJSON(raw) or nil
    if type(manifest) ~= "table" or type(manifest.version) ~= "string" or type(manifest.managed) ~= "table" then return nil end
    return manifest
end

function M.releaseNotice(reason)
    local manifest = M.localManifest()
    return {version=M.localVersion(),manifest=manifest,issuedBy=os.getComputerID(),reason=reason or "fleet"}
end

function M.remoteVersion()
    local headSha, headErr = getHeadSha()
    if not headSha then return nil, headErr end
    local body, err = fetchRaw(headSha, "manifest.json")
    if not body then return nil, err end
    local manifest = textutils.unserializeJSON(body)
    if type(manifest) ~= "table" or type(manifest.version) ~= "string" then return nil, "invalid manifest" end
    manifest._head = headSha
    return manifest.version, manifest
end

function M.check()
    local remote, manifestOrErr = M.remoteVersion()
    if not remote then return nil, manifestOrErr end
    local current = M.localVersion()
    return { current=current, remote=remote, available=current~=remote, manifest=manifestOrErr }
end

function M.autoEnabled(cfg) return cfg and cfg.update and cfg.update.auto ~= false end
function M.fleetManaged(cfg) return not (cfg and cfg.update and cfg.update.fleetManaged == false) end
function M.checkOnBoot(cfg) return not (cfg and cfg.update and cfg.update.checkOnBoot == false) end
function M.interval(cfg)
    local n = cfg and cfg.update and tonumber(cfg.update.interval) or 600
    return math.max(60, n)
end

function M.request(targetVersion, reason, manifest)
    if not fs.exists(ROOT) then fs.makeDir(ROOT) end
    writeFile(REQUESTED, textutils.serialize({target=targetVersion,reason=reason or "fleet",manifest=type(manifest)=="table" and manifest or nil,requested=os.epoch("utc")}))
end

function M.requestLiveReload(reason)
    if not fs.exists(ROOT) then fs.makeDir(ROOT) end
    writeFile(RELOAD,textutils.serialize({reason=reason or "reload",at=os.epoch("utc")}))
end

function M.hasPendingProbation() return fs.exists(PENDING) end

function M.markHealthy()
    if not fs.exists(PENDING) then return false end
    local raw = readFile(PENDING)
    local pending = raw and textutils.unserialize(raw) or nil
    if type(pending) == "table" then
        pending.healthy = os.epoch("utc")
        writeFile(ROOT .. "/last_good_update", textutils.serialize(pending))
    end
    fs.delete(PENDING)
    if fs.exists(ROLLBACK) then fs.delete(ROLLBACK) end
    if fs.exists(STAGING) then fs.delete(STAGING) end
    return true
end

-- Compatibility name kept so older roles do not need a flag day. Starting with
-- alpha73 this performs the transactional install in-process, then deliberately
-- unwinds the current KIMI program back to startup.lua. startup.lua launches a
-- fresh program environment from the new files without rebooting the CC computer.
function M.rebootForUpdate(targetVersion, reason, manifest)
    M.request(targetVersion, reason, manifest)
    term.setTextColor(colors.yellow)
    print("[KIMI] live updating" .. (targetVersion and (" -> " .. tostring(targetVersion)) or ""))
    term.setTextColor(colors.white)
    local ok = shell.run("updater", "auto")
    if ok == false then error("KIMI live update install failed",0) end
    M.requestLiveReload("installed:"..tostring(targetVersion or "unknown"))
    error(M.RELOAD_SENTINEL,0)
end

function M.periodic(updateCfg)
    updateCfg = updateCfg or {}
    if updateCfg.auto == false then while true do sleep(3600) end end
    local interval = math.max(60, tonumber(updateCfg.interval) or 600)
    while true do
        sleep(interval)
        local result = M.check()
        if result and result.available then M.rebootForUpdate(result.remote, "kernel-periodic-check", result.manifest) end
    end
end

return M