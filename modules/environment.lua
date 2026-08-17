local M = { id = "environment" }

local moonPhases = {
    "FULL MOON", "WANING GIBBOUS", "THIRD QUARTER", "WANING CRESCENT",
    "NEW MOON", "WAXING CRESCENT", "FIRST QUARTER", "WAXING GIBBOUS"
}

local function findDetector()
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "environment_detector") then
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
    local day = os.day("ingame")
    local out = {
        sensor = name,
        online = detector ~= nil,
        weather = "UNKNOWN",
        biome = "UNKNOWN",
        dimension = "UNKNOWN",
        blockLight = 0,
        skyLight = 0,
        moon = moonPhases[(day % 8) + 1],
        _updated = os.epoch("utc")
    }

    if not detector then
        out._status = "offline"
        return out
    end

    local thunder, thunderOk = call(detector, "isThunder", false)
    local rain, rainOk = call(detector, "isRaining", false)
    local sunny, sunnyOk = call(detector, "isSunny", false)
    if not (thunderOk or rainOk or sunnyOk) then error("environment detector weather calls failed") end

    if thunder then out.weather = "THUNDER"
    elseif rain then out.weather = "RAINING"
    elseif sunny then out.weather = "SUNNY"
    else out.weather = "CLEAR" end

    out.biome = call(detector, "getBiome", "UNKNOWN")
    out.dimension = call(detector, "getDimension", "UNKNOWN")
    out.blockLight = call(detector, "getBlockLightLevel", 0)
    out.skyLight = call(detector, "getSkyLightLevel", 0)
    return out
end

return M
