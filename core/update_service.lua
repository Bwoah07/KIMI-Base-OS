local M = {}

local ROOT = ".kimi"
local PENDING = ROOT .. "/update_pending"
local REQUESTED = ROOT .. "/update_requested"
local MANIFEST_URL = "https://raw.githubusercontent.com/Bwoah07/KIMI-Base-OS/main/manifest.json"

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

function M.localVersion()
    return ((readFile("version.txt") or "not-installed"):gsub("%s+$", ""))
end

function M.remoteVersion()
    local url = MANIFEST_URL .. "?kimi_cb=" .. tostring(os.epoch("utc"))
    local r, err = http.get(url)
    if not r then return nil, err end
    local body = r.readAll(); r.close()
    if not body or body == "" then return nil, "empty manifest response" end
    local manifest = textutils.unserializeJSON(body)
    if type(manifest) ~= "table" or type(manifest.version) ~= "string" then
        return nil, "invalid manifest"
    end
    return manifest.version, manifest
end

function M.check()
    local remote, manifestOrErr = M.remoteVersion()
    if not remote then return nil, manifestOrErr end
    local current = M.localVersion()
    return {
        current = current,
        remote = remote,
        available = current ~= remote,
        manifest = manifestOrErr
    }
end

function M.autoEnabled(cfg)
    return cfg and cfg.update and cfg.update.auto ~= false
end

function M.interval(cfg)
    local n = cfg and cfg.update and tonumber(cfg.update.interval) or 600
    return math.max(60, n)
end

function M.request(targetVersion, reason)
    if not fs.exists(ROOT) then fs.makeDir(ROOT) end
    writeFile(REQUESTED, textutils.serialize({
        target = targetVersion,
        reason = reason or "fleet",
        requested = os.epoch("utc")
    }))
end

function M.hasPendingProbation()
    return fs.exists(PENDING)
end

function M.markHealthy()
    if not fs.exists(PENDING) then return false end
    local raw = readFile(PENDING)
    local pending = raw and textutils.unserialize(raw) or nil
    if type(pending) == "table" then
        pending.healthy = os.epoch("utc")
        writeFile(ROOT .. "/last_good_update", textutils.serialize(pending))
    end
    fs.delete(PENDING)
    return true
end

function M.rebootForUpdate(targetVersion, reason)
    M.request(targetVersion, reason)
    term.setTextColor(colors.yellow)
    print("[KIMI] rebooting for update" .. (targetVersion and (" -> " .. tostring(targetVersion)) or ""))
    term.setTextColor(colors.white)
    sleep(1)
    os.reboot()
end

return M
