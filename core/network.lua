local M = {}

local function modemNames()
    local out = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "modem") then out[#out + 1] = name end
    end
    return out
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
    return rednet.send(id, { kind = kind, payload = payload, sent = os.epoch("utc") }, cfg.network.protocol)
end

return M
