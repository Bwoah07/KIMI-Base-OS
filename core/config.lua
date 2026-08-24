local M = {}
local ROOT = ".kimi"
local PATH = ROOT .. "/config"

local function computerLabel()
    local label = type(os.getComputerLabel) == "function" and os.getComputerLabel() or nil
    if label and tostring(label):match("%S") then return tostring(label) end
    return nil
end

local function generatedName()
    return "KIMI-" .. tostring(os.getComputerID())
end

local defaults = {
    role = "client",
    profile = "wall",
    name = generatedName(),
    theme = { accent = "red" },
    network = { protocol = "kimi_base_os_v1", hostname = "kimi-base" },
    update = {
        channel = "alpha",
        auto = true,
        checkOnBoot = true,
        interval = 600
    }
}

local function merge(dst, src)
    for k, v in pairs(src or {}) do
        if type(v) == "table" and type(dst[k]) == "table" then merge(dst[k], v) else dst[k] = v end
    end
    return dst
end

function M.load()
    if not fs.exists(ROOT) then fs.makeDir(ROOT) end
    local cfg = textutils.unserialize(textutils.serialize(defaults))
    if fs.exists(PATH) then
        local f = fs.open(PATH, "r")
        local raw = f and f.readAll() or nil
        if f then f.close() end
        local parsed = raw and textutils.unserialize(raw) or nil
        if type(parsed) == "table" then merge(cfg, parsed) end
    end

    -- Old installs were named KIMI-<computer id>. If the player gave the
    -- ComputerCraft computer a real label, use that label automatically in
    -- dashboards/fleet views. Explicit custom KIMI config names still win.
    local label = computerLabel()
    if label and (not cfg.name or cfg.name == "" or cfg.name == generatedName()) then
        cfg.name = label
    end
    return cfg
end

function M.save(cfg)
    if not fs.exists(ROOT) then fs.makeDir(ROOT) end
    local f = assert(fs.open(PATH, "w"))
    f.write(textutils.serialize(cfg))
    f.close()
end

function M.path() return PATH end
return M
