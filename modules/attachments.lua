local M = { id = "attachments" }

local function safeCall(obj, method, fallback, ...)
    if not obj or type(obj[method]) ~= "function" then return fallback, false end
    local ok, value = pcall(obj[method], ...)
    if not ok or value == nil then return fallback, false end
    return value, true
end

local function getTypes(name)
    local result = { pcall(peripheral.getType, name) }
    if not result[1] then return { "unknown" } end
    table.remove(result, 1)
    local out, seen = {}, {}
    for _, value in ipairs(result) do
        if type(value) == "string" and not seen[value] then seen[value] = true; out[#out + 1] = value end
    end
    if #out == 0 then out[1] = "unknown" end
    table.sort(out)
    return out
end

local function getMethods(name)
    local ok, value = pcall(peripheral.getMethods, name)
    if not ok or type(value) ~= "table" then return {}, {} end
    local out, set = {}, {}
    for _, method in ipairs(value) do
        if type(method) == "string" and not set[method] then set[method] = true; out[#out + 1] = method end
    end
    table.sort(out)
    return out, set
end

local function contains(text, needle)
    return tostring(text or ""):lower():find(needle, 1, true) ~= nil
end

local sensorTypeWords = {
    "sensor", "detector", "scanner", "reader", "analyzer", "analyser", "observer",
    "thermometer", "barometer", "seismometer", "radiation", "weather", "environment",
    "biome", "player_detector", "entity_detector", "block_reader", "geo_scanner"
}

local sensorMethods = {
    getTemperature=true, getHumidity=true, getRadiation=true, getPressure=true,
    getBiome=true, getDimension=true, getBlockLightLevel=true, getSkyLightLevel=true,
    isRaining=true, isThunder=true, isSunny=true, getMoonPhase=true,
    getOnlinePlayers=true, getPlayersInRange=true, getPlayerCount=true,
    getEntitiesInRange=true, getEntityCount=true, getBlockData=true, getBlockName=true,
    getMaxScanRadius=true
}

local function classify(types, methods)
    local joined = table.concat(types, " "):lower()
    local categories, set = {}, {}
    local function add(value)
        if not set[value] then set[value] = true; categories[#categories + 1] = value end
    end

    local sensorType = false
    for _, word in ipairs(sensorTypeWords) do if contains(joined, word) then sensorType = true; break end end
    local sensorMethod = false
    for method in pairs(sensorMethods) do if methods[method] then sensorMethod = true; break end end
    if sensorType or sensorMethod then add("sensor") end

    if contains(joined, "flux") or contains(joined, "energy") or contains(joined, "induction") or
       methods.getEnergy or methods.getStoredEnergy or methods.getTransferRate then add("power") end
    if contains(joined, "redstone") or contains(joined, "door") or contains(joined, "gate") or
       methods.setOutput or methods.open or methods.setOpen then add("control") end
    if contains(joined, "inventory") or contains(joined, "storage") or contains(joined, "tank") or
       methods.list or methods.tanks or methods.size then add("storage") end
    if contains(joined, "monitor") or contains(joined, "printer") or contains(joined, "speaker") then add("display") end
    if contains(joined, "modem") or contains(joined, "bridge") or contains(joined, "network") then add("network") end
    if contains(joined, "computer") or contains(joined, "turtle") or contains(joined, "drive") then add("computer") end
    if #categories == 0 then add("peripheral") end
    return categories
end

local function countTable(value)
    if type(value) ~= "table" then return nil end
    local n = 0
    for _ in pairs(value) do n = n + 1 end
    return n
end

local function snapshot(obj, methods)
    local metrics = {}
    local function add(key, method, fallback, ...)
        if methods[method] then
            local value, ok = safeCall(obj, method, fallback, ...)
            if ok then metrics[key] = value end
        end
    end

    add("weatherRaining", "isRaining", false)
    add("weatherThunder", "isThunder", false)
    add("weatherSunny", "isSunny", false)
    add("biome", "getBiome", nil)
    add("dimension", "getDimension", nil)
    add("blockLight", "getBlockLightLevel", nil)
    add("skyLight", "getSkyLightLevel", nil)
    add("temperature", "getTemperature", nil)
    add("humidity", "getHumidity", nil)
    add("pressure", "getPressure", nil)
    add("radiation", "getRadiation", nil)
    add("moonPhase", "getMoonPhase", nil)
    add("slimeChunk", "isSlimeChunk", nil)
    add("block", "getBlockName", nil)
    add("blockData", "getBlockData", nil)
    add("fuel", "getFuelLevel", nil)
    add("maxScanRadius", "getMaxScanRadius", nil)
    add("energy", "getEnergy", nil)
    add("storedEnergy", "getStoredEnergy", nil)
    add("energyCapacity", "getEnergyCapacity", nil)
    add("maxEnergy", "getMaxEnergy", nil)
    add("transferRate", "getTransferRate", nil)
    add("networkName", "getNetworkName", nil)
    add("colonyName", "getColonyName", nil)
    add("colonyId", "getColonyID", nil)
    add("owner", "getOwner", nil)
    add("inventorySize", "size", nil)
    add("playerCount", "getPlayerCount", nil)
    add("entityCount", "getEntityCount", nil)
    add("range", "getRange", nil)

    if methods.getOnlinePlayers then
        local players, ok = safeCall(obj, "getOnlinePlayers", nil)
        if ok and type(players) == "table" then metrics.onlinePlayers = countTable(players); metrics.players = players end
    end
    return metrics
end

local function summary(metrics)
    if metrics.biome or metrics.dimension then return tostring(metrics.biome or "?") .. " / " .. tostring(metrics.dimension or "?") end
    if metrics.onlinePlayers ~= nil then return tostring(metrics.onlinePlayers) .. " player(s) online" end
    if metrics.playerCount ~= nil then return tostring(metrics.playerCount) .. " player(s)" end
    if metrics.entityCount ~= nil then return tostring(metrics.entityCount) .. " entities" end
    if metrics.temperature ~= nil then return "Temperature " .. tostring(metrics.temperature) end
    if metrics.radiation ~= nil then return "Radiation " .. tostring(metrics.radiation) end
    if metrics.humidity ~= nil then return "Humidity " .. tostring(metrics.humidity) end
    if metrics.pressure ~= nil then return "Pressure " .. tostring(metrics.pressure) end
    if metrics.block then return "Block " .. tostring(metrics.block) end
    if metrics.networkName then return "Network " .. tostring(metrics.networkName) end
    if metrics.transferRate ~= nil then return tostring(metrics.transferRate) .. " FE/t" end
    if metrics.storedEnergy ~= nil or metrics.energy ~= nil then return tostring(metrics.storedEnergy or metrics.energy) .. " FE" end
    if metrics.colonyName then return "Colony " .. tostring(metrics.colonyName) end
    if metrics.fuel ~= nil then return "Fuel " .. tostring(metrics.fuel) end
    if metrics.inventorySize ~= nil then return tostring(metrics.inventorySize) .. " slots" end
    return "Telemetry peripheral"
end

function M.read()
    local devices, sensors, counts = {}, {}, {}
    local names = peripheral.getNames(); table.sort(names)
    for _, name in ipairs(names) do
        local types = getTypes(name)
        local methodList, methodLookup = getMethods(name)
        local obj = peripheral.wrap(name)
        local categories = classify(types, methodLookup)
        local metrics = snapshot(obj, methodLookup)
        local entry = {
            name=name, type=types[1], types=types, categories=categories,
            methods=methodList, methodCount=#methodList, metrics=metrics,
            summary=summary(metrics), online=obj ~= nil
        }
        devices[#devices + 1] = entry
        for _, category in ipairs(categories) do counts[category] = (counts[category] or 0) + 1 end
        for _, category in ipairs(categories) do if category == "sensor" then sensors[#sensors + 1] = entry; break end end
    end
    return {
        count=#devices, sensorCount=#sensors, devices=devices, sensors=sensors, categories=counts,
        _status="online", _updated=os.epoch("utc")
    }
end

return M
