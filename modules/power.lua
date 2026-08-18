local M = { id = "power" }

local function findDetector()
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "energy_detector") or peripheral.getType(name) == "energy_detector" then
            return peripheral.wrap(name), name
        end
    end
end

local function call(obj, method, fallback)
    if not obj or type(obj[method]) ~= "function" then return fallback, false end
    local ok, value = pcall(obj[method])
    if not ok or value == nil then return fallback, false end
    return value, true
end

function M.read(previous)
    local detector, name = findDetector()
    local out = {
        detector = name,
        transferRate = nil,
        transferRateLimit = nil,
        maxTransferRate = nil,
        stored = nil,
        capacity = nil,
        input = nil,
        output = nil,
        status = "OFFLINE",
        _updated = os.epoch("utc")
    }

    if not detector then
        out._status = "offline"
        return out
    end

    out.transferRate = call(detector, "getTransferRate", nil)
    out.transferRateLimit = call(detector, "getTransferRateLimit", nil)
    out.maxTransferRate = call(detector, "getMaxTransferRate", nil)
    out.input = out.transferRate
    out.output = out.transferRate
    out.status = "ONLINE"
    out._status = "online"
    return out
end

return M
