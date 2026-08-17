local M = {}
local ROOT = ".kimi"
local PATH = ROOT .. "/config"

local defaults = {
    role = "client",
    profile = "wall",
    name = "KIMI-" .. tostring(os.getComputerID()),
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
        local raw = f.readAll()
        f.close()
        local parsed = textutils.unserialize(raw)
        if type(parsed) == "table" then merge(cfg, parsed) end
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
