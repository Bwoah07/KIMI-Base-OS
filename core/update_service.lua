local M = {}

local OWNER, REPO, BRANCH = "Bwoah07", "KIMI-Base-OS", "main"
local MANIFEST_URL = "https://raw.githubusercontent.com/" .. OWNER .. "/" .. REPO .. "/" .. BRANCH .. "/manifest.json"
local ROOT = ".kimi"
local PENDING = ROOT .. "/update_pending"

local function readFile(path)
    if not fs.exists(path) or fs.isDir(path) then return nil end
    local f = fs.open(path, "r")
    if not f then return nil end
    local data = f.readAll()
    f.close()
    return data
end

local function writeFile(path, data)
    local dir = fs.getDir(path)
    if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
    local f = assert(fs.open(path, "w"))
    f.write(data)
    f.close()
end

local function localVersion()
    local v = readFile("version.txt") or "not-installed"
    return (v:gsub("%s+$", ""))
end

local function remoteManifest()
    local response, err = http.get(MANIFEST_URL)
    if not response then return nil, err end
    local body = response.readAll()
    response.close()
    local parsed = textutils.unserializeJSON(body)
    if type(parsed) ~= "table" or type(parsed.version) ~= "string" then
        return nil, "invalid remote manifest"
    end
    return parsed
end

function M.isPending()
    return fs.exists(PENDING)
end

function M.markHealthy()
    if fs.exists(PENDING) then fs.delete(PENDING) end
end

function M.check()
    local manifest, err = remoteManifest()
    if not manifest then return nil, err end
    return manifest.version ~= localVersion(), manifest.version
end

function M.requestUpdate(version)
    writeFile(ROOT .. "/update_requested", textutils.serialize({
        version = version,
        requested = os.epoch("utc")
    }))
end

function M.periodic(updateCfg)
    updateCfg = updateCfg or {}
    if updateCfg.auto == false then
        while true do sleep(3600) end
    end

    local interval = tonumber(updateCfg.interval) or 600
    interval = math.max(60, interval)

    while true do
        sleep(interval)
        local available, value = M.check()
        if available == true then
            term.setTextColor(colors.yellow)
            print("[KIMI] update " .. tostring(value) .. " available; rebooting to install...")
            term.setTextColor(colors.white)
            M.requestUpdate(value)
            sleep(2)
            os.reboot()
        elseif available == nil then
            -- Internet/GitHub failures are intentionally non-fatal.
        end
    end
end

return M
