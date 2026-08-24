local M = {}

local function modemNames()
    local out = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "modem") then out[#out + 1] = name end
    end
    return out
end

local function readInstalledManifest()
    local path = ".kimi/installed_manifest.json"
    if not fs.exists(path) or fs.isDir(path) then return nil end
    local f = fs.open(path, "r")
    if not f then return nil end
    local raw = f.readAll(); f.close()
    local manifest = raw and textutils.unserializeJSON(raw) or nil
    if type(manifest) ~= "table" or type(manifest.version) ~= "string" or type(manifest.managed) ~= "table" then return nil end
    return manifest
end

local function enrich(kind, payload)
    if kind ~= "update.available" or type(payload) ~= "table" or payload.manifest ~= nil then return payload end
    local manifest = readInstalledManifest()
    if manifest and tostring(manifest.version) == tostring(payload.version or "") then
        local copy = {}
        for k, v in pairs(payload) do copy[k] = v end
        copy.manifest = manifest
        return copy
    end
    return payload
end

function M.openAll()
    local opened = 0
    for _, name in ipairs(modemNames()) do
        local ok = pcall(rednet.open, name)
        if ok then opened = opened + 1 end
    end
    return opened
end

function M.host(cfg)
    M.openAll()
    pcall(rednet.unhost, cfg.network.protocol)
    rednet.host(cfg.network.protocol, cfg.network.hostname)
end

function M.findServer(cfg)
    M.openAll()
    return rednet.lookup(cfg.network.protocol, cfg.network.hostname)
end

function M.send(id, cfg, kind, payload)
    payload = enrich(kind, payload)
    return rednet.send(id, { kind = kind, payload = payload, sent = os.epoch("utc") }, cfg.network.protocol)
end

return M
