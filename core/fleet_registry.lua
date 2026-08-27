local M = {}
local ROOT = ".kimi"
local PATH = ROOT .. "/fleet_registry"

local function readFile(path)
    if not fs.exists(path) or fs.isDir(path) then return nil end
    local f = fs.open(path, "r")
    if not f then return nil end
    local body = f.readAll(); f.close(); return body
end

local function clean(entry)
    if type(entry) ~= "table" then return nil end
    return {
        firstSeen = tonumber(entry.firstSeen), lastSeen = tonumber(entry.lastSeen),
        role = entry.role, name = entry.name, profile = entry.profile, version = entry.version,
        updateTarget = entry.updateTarget, updateStatus = entry.updateStatus,
        hostname = entry.hostname, sessionId = entry.sessionId, online = false
    }
end

function M.load()
    local raw = readFile(PATH)
    local parsed = raw and textutils.unserialize(raw) or nil
    if type(parsed) ~= "table" then return {} end
    local out = {}
    for id, entry in pairs(parsed) do
        local value = clean(entry); local numeric = tonumber(id)
        if value and numeric then out[numeric] = value end
    end
    return out
end

function M.save(machines)
    if not fs.exists(ROOT) then fs.makeDir(ROOT) end
    local out = {}
    for id, entry in pairs(machines or {}) do
        local value = clean(entry)
        if value then value.online = nil; out[tostring(id)] = value end
    end
    local f = assert(fs.open(PATH, "w")); f.write(textutils.serialize(out)); f.close()
    return true
end

return M
