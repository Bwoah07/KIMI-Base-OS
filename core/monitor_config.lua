local M = {}
local ROOT = ".kimi"
local PATH = ROOT .. "/monitors"

local views = {
    "auto", "overview", "doors", "power", "fleet",
    "builder", "weather", "sensors", "ae2", "system"
}
local allowed = {}
for _, v in ipairs(views) do allowed[v] = true end

local function ensureRoot()
    if not fs.exists(ROOT) then fs.makeDir(ROOT) end
end

local function normalizeView(v)
    v = tostring(v or "auto"):lower()
    if not allowed[v] then return "auto" end
    return v
end

local function normalize(data)
    local out = { version = 1, assignments = {} }
    if type(data) ~= "table" then return out end
    local src = type(data.assignments) == "table" and data.assignments or data
    for name, view in pairs(src) do
        if type(name) == "string" and name ~= "" then
            out.assignments[name] = normalizeView(view)
        end
    end
    return out
end

function M.views()
    local out = {}
    for i, v in ipairs(views) do out[i] = v end
    return out
end

function M.normalizeView(v) return normalizeView(v) end

function M.load()
    if not fs.exists(PATH) or fs.isDir(PATH) then return normalize(nil) end
    local f = fs.open(PATH, "r")
    if not f then return normalize(nil) end
    local raw = f.readAll()
    f.close()
    return normalize(textutils.unserialize(raw))
end

function M.save(data)
    ensureRoot()
    local clean = normalize(data)
    local tmp = PATH .. ".tmp"
    local f = assert(fs.open(tmp, "w"))
    f.write(textutils.serialize(clean))
    f.close()
    if fs.exists(PATH) and not fs.isDir(PATH) then fs.delete(PATH) end
    fs.move(tmp, PATH)
    return clean
end

function M.get(data, monitorName)
    local clean = normalize(data)
    return clean.assignments[tostring(monitorName or "")] or "auto"
end

function M.set(data, monitorName, view)
    local clean = normalize(data)
    local name = tostring(monitorName or "")
    if name == "" then return clean end
    clean.assignments[name] = normalizeView(view)
    return clean
end

function M.path() return PATH end
return M
