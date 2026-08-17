local M = {}

local moonPhases = {
    "FULL MOON",
    "WANING GIBBOUS",
    "THIRD QUARTER",
    "WANING CRESCENT",
    "NEW MOON",
    "WAXING CRESCENT",
    "FIRST QUARTER",
    "WAXING GIBBOUS"
}

local function safeCall(obj, methodName, default)
    if not obj then return default end
    local fn = obj[methodName]
    if type(fn) ~= "function" then return default end
    local ok, value = pcall(fn)
    if not ok or value == nil then return default end
    return value
end

local function findDetector()
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "environment_detector") then
            return peripheral.wrap(name), name
        end
    end
    return nil, nil
end

function M.read()
    local detector, name = findDetector()
    local now = os.epoch("utc")
    local day = os.day("ingame")

    local out = {
        online = detector ~= nil,
        name = name,
        updated = now,
        weather = "UNKNOWN",
        biome = "UNKNOWN",
        dimension = "UNKNOWN",
        blockLight = 0,
        skyLight = 0,
        moon = moonPhases[(day % 8) + 1]
    }

    if not detector then
        out.updated = nil
        return out
    end

    local thunder = safeCall(detector, "isThunder", false)
    local raining = safeCall(detector, "isRaining", false)
    local sunny = safeCall(detector, "isSunny", not raining and not thunder)

    if thunder then
        out.weather = "THUNDER"
    elseif raining then
        out.weather = "RAINING"
    elseif sunny then
        out.weather = "SUNNY"
    else
        out.weather = "CLEAR"
    end

    out.biome = safeCall(detector, "getBiome", "UNKNOWN")
    out.dimension = safeCall(detector, "getDimension", "UNKNOWN")
    out.blockLight = safeCall(detector, "getBlockLightLevel", 0)
    out.skyLight = safeCall(detector, "getSkyLightLevel", 0)

    return out
end

return M
