local M = { id = "power" }

local function call(obj, method, fallback, ...)
    if not obj or type(obj[method]) ~= "function" then return fallback, false end
    local result = { pcall(obj[method], ...) }
    if not result[1] or result[2] == nil then return fallback, false end
    return result[2], true, result[3]
end

local function methodSet(name)
    local ok, methods = pcall(peripheral.getMethods, name)
    local set = {}
    if ok and type(methods) == "table" then
        for _, method in ipairs(methods) do set[method] = true end
    end
    return set
end

local function hasMethods(methods, required)
    for _, method in ipairs(required) do
        if not methods[method] then return false end
    end
    return true
end

local function hasType(name, wanted)
    if type(peripheral.hasType) == "function" then
        local ok, value = pcall(peripheral.hasType, name, wanted)
        if ok and value then return true end
    end
    local ok, value = pcall(peripheral.getType, name)
    return ok and value == wanted
end

local function copy(src)
    local out = {}
    for key, value in pairs(src or {}) do out[key] = value end
    return out
end

local function countList(value)
    if type(value) ~= "table" then return 0 end
    local n = 0
    for _ in pairs(value) do n = n + 1 end
    return n
end

local function readFluxController(obj, name)
    local stats = call(obj, "getNetworkStats", nil)
    if type(stats) ~= "table" then stats = {} end

    local networkName = stats.name or call(obj, "getNetworkName", "UNKNOWN")
    local networkId = stats.id or call(obj, "getNetworkId", nil)
    if networkId == nil then networkId = call(obj, "getNetworkID", nil) end

    local stored = stats.stored or call(obj, "getStoredEnergy", nil)
    if stored == nil then stored = call(obj, "getEnergy", nil) end
    local capacity = stats.capacity or call(obj, "getEnergyCapacity", nil)
    local input = stats.input or call(obj, "getEnergyInput", nil)
    local output = stats.output or call(obj, "getEnergyOutput", nil)
    local net = stats.net or call(obj, "getNetEnergy", nil)
    if net == nil and type(input) == "number" and type(output) == "number" then net = input - output end

    local devices = call(obj, "getDevices", nil)
    local warnings = call(obj, "getWarnings", nil)
    local health = call(obj, "getHealth", nil)
    local valid = call(obj, "isValid", true)
    local healthy = valid ~= false
    local status = valid == false and "DEGRADED" or "ONLINE"
    if type(health) == "table" then
        if health.healthy == false then healthy = false end
        status = tostring(health.status or status):upper()
    end

    local plugs = stats.plugs or call(obj, "getPlugCount", nil)
    if plugs == nil then plugs = call(obj, "getPlugsCount", nil) end
    local points = stats.points or call(obj, "getPointCount", nil)
    local storages = stats.storages or call(obj, "getStorageCount", nil)
    local controllers = stats.controllers or call(obj, "getControllerCount", nil)
    local deviceCount = stats.devices or call(obj, "getDeviceCount", nil)
    if deviceCount == nil and type(devices) == "table" then deviceCount = countList(devices) end

    local filled
    if type(stored) == "number" and type(capacity) == "number" and capacity > 0 then
        filled = stored / capacity
    end

    return {
        sourceType = "flux_network",
        api = type(obj.getNetworkStats) == "function" and "flux_controller_fork" or "flux_device",
        peripheral = name,
        peripherals = { name },
        networkName = networkName,
        networkId = networkId,
        stored = stored,
        storedExact = stats.storedExact or call(obj, "getStoredEnergyExact", nil),
        capacity = capacity,
        capacityExact = stats.capacityExact or call(obj, "getEnergyCapacityExact", nil),
        input = input,
        inputExact = stats.inputExact or call(obj, "getEnergyInputExact", nil),
        output = output,
        outputExact = stats.outputExact or call(obj, "getEnergyOutputExact", nil),
        net = net,
        netExact = stats.netExact or call(obj, "getNetEnergyExact", nil),
        buffer = call(obj, "getEnergyBuffer", nil),
        devices = devices,
        deviceCount = deviceCount,
        plugs = plugs,
        points = points,
        storages = storages,
        controllers = controllers,
        warnings = warnings,
        warningCount = countList(warnings),
        healthy = healthy,
        avgTickUs = stats.averageTickMicroseconds or call(obj, "getAVGTickUs", nil),
        security = call(obj, "getSecurityLevel", nil),
        filledPercentage = filled,
        status = status,
        _status = healthy and "online" or "degraded",
        _updated = os.epoch("utc")
    }
end

local function fluxControllers()
    local out = {}
    local grouped = {}
    for _, name in ipairs(peripheral.getNames()) do
        local methods = methodSet(name)
        local isFork = hasType(name, "flux_controller") or hasMethods(methods, { "getNetworkStats", "getDevices", "getWarnings" })
        local isLegacy = hasType(name, "flux_device") or hasMethods(methods, { "getNetworkName", "getEnergyInput", "getEnergyOutput", "getEnergy" })
        if isFork or isLegacy then
            local wrapped = peripheral.wrap(name)
            if wrapped then
                local value = readFluxController(wrapped, name)
                local key = tostring(value.networkId or value.networkName or name)
                local existing = grouped[key]
                if existing then
                    existing.peripherals[#existing.peripherals + 1] = name
                    if (value.warningCount or 0) > (existing.warningCount or 0) then
                        existing.warnings = value.warnings
                        existing.warningCount = value.warningCount
                        existing.healthy = value.healthy
                        existing.status = value.status
                        existing._status = value._status
                    end
                    if countList(value.devices) > countList(existing.devices) then existing.devices = value.devices end
                else
                    grouped[key] = value
                    out[#out + 1] = value
                end
            end
        end
    end
    table.sort(out, function(a, b)
        return tostring(a.networkName or a.peripheral) < tostring(b.networkName or b.peripheral)
    end)
    return out
end

local function readMatrix(obj, name)
    local energy = call(obj, "getEnergy", nil)
    local capacity = call(obj, "getMaxEnergy", nil)
    local input = call(obj, "getLastInput", nil)
    local output = call(obj, "getLastOutput", nil)
    local filled = call(obj, "getEnergyFilledPercentage", nil)
    if filled == nil and type(energy) == "number" and type(capacity) == "number" and capacity > 0 then
        filled = energy / capacity
    end
    return {
        sourceType = "mekanism_induction_port",
        peripheral = name,
        stored = energy,
        capacity = capacity,
        input = input,
        output = output,
        transferCap = call(obj, "getTransferCap", nil),
        filledPercentage = filled,
        energyNeeded = call(obj, "getEnergyNeeded", nil),
        installedCells = call(obj, "getInstalledCells", nil),
        installedProviders = call(obj, "getInstalledProviders", nil),
        mode = call(obj, "getMode", nil),
        comparatorLevel = call(obj, "getComparatorLevel", nil),
        net = (type(input) == "number" and type(output) == "number") and (input - output) or nil,
        status = "ONLINE",
        _status = "online",
        _updated = os.epoch("utc")
    }
end

local function matrices()
    local out = {}
    for _, name in ipairs(peripheral.getNames()) do
        local methods = methodSet(name)
        if hasMethods(methods, { "getEnergy", "getMaxEnergy", "getLastInput", "getLastOutput", "getTransferCap" }) then
            local wrapped = peripheral.wrap(name)
            if wrapped then out[#out + 1] = readMatrix(wrapped, name) end
        end
    end
    table.sort(out, function(a, b) return a.peripheral < b.peripheral end)
    return out
end

local function detectors()
    local out = {}
    for _, name in ipairs(peripheral.getNames()) do
        local methods = methodSet(name)
        if hasType(name, "energy_detector") or methods.getTransferRate then
            local obj = peripheral.wrap(name)
            if obj then
                local rate = call(obj, "getTransferRate", nil)
                out[#out + 1] = {
                    sourceType = "energy_detector",
                    peripheral = name,
                    transferRate = rate,
                    transferRateLimit = call(obj, "getTransferRateLimit", nil),
                    maxTransferRate = call(obj, "getMaxTransferRate", nil),
                    input = rate,
                    output = rate,
                    status = "ONLINE",
                    _status = "online",
                    _updated = os.epoch("utc")
                }
            end
        end
    end
    table.sort(out, function(a, b) return a.peripheral < b.peripheral end)
    return out
end

function M.read()
    local flux = fluxControllers()
    local matrix = matrices()
    local detector = detectors()
    local primary = flux[1] or matrix[1] or detector[1]
    local out = copy(primary)

    out.fluxNetworks = flux
    out.matrices = matrix
    out.energyDetectors = detector
    out.fluxCount = #flux
    out.matrixCount = #matrix
    out.detectorCount = #detector
    out.onlineSources = #flux + #matrix + #detector
    out._updated = os.epoch("utc")

    if primary then
        out.status = primary.status or "ONLINE"
        out._status = primary._status or "online"
    else
        out.sourceType = nil
        out.peripheral = nil
        out.stored = nil
        out.capacity = nil
        out.input = nil
        out.output = nil
        out.status = "OFFLINE"
        out._status = "offline"
    end

    return out
end

return M
