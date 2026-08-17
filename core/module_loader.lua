local M = {}

local function moduleName(path)
    return path:gsub("/", "."):gsub("%.lua$", "")
end

function M.discover(dir)
    dir = dir or "modules"
    local out = {}
    if not fs.exists(dir) then return out end
    for _, file in ipairs(fs.list(dir)) do
        local path = fs.combine(dir, file)
        if not fs.isDir(path) and file:match("%.lua$") then
            local ok, mod = pcall(require, moduleName(path))
            if ok and type(mod) == "table" and mod.id then
                out[mod.id] = mod
            else
                print("[KIMI] module load failed: " .. path .. " " .. tostring(mod))
            end
        end
    end
    return out
end

function M.readAll(modules, previous)
    local state = {}
    for id, mod in pairs(modules) do
        local ok, value = pcall(mod.read, previous and previous[id])
        if ok and type(value) == "table" then
            value._status = value._status or "online"
            value._updated = value._updated or os.epoch("utc")
            state[id] = value
        else
            local old = previous and previous[id] or {}
            old._status = "error"
            old._error = tostring(value)
            old._failedAt = os.epoch("utc")
            state[id] = old
        end
    end
    return state
end

return M
