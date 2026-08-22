local M = { id = "power" }

local function call(obj, method, fallback)
    if not obj or type(obj[method]) ~= "function" then return fallback, false end
    local ok, value = pcall(obj[method])
    if not ok or value == nil then return fallback, false end
    return value, true
end

local function hasMethods(name, required)
    local methods = peripheral.getMethods(name) or {}
    local set = {}
    for _, m in ipairs(methods) do set[m] = true end
    for _, m in ipairs(required) do
        if not set[m] then return false end
    end
    return true
end

-- Flux Networks CC:Tweaked support (native/fork builds exposing flux_device).
-- We also detect by method signature so this survives peripheral-name changes.
local function findFluxDevice()
    local required = { "getNetworkName", "getEnergyInput", "getEnergyOutput", "getEnergy" }
    for _, name in ipairs(peripheral.getNames()) do
        local ptype = peripheral.getType(name)
        local isFluxType = peripheral.hasType(name, "flux_device") or ptype == "flux_device"
        if isFluxType or hasMethods(name, required) then
            local wrapped = peripheral.wrap(name)
            if wrapped then return wrapped, name end
        end
    end
end

local function findInductionPort()
    for _, name in ipairs(peripheral.getNames()) do
        if hasMethods(name, { "getEnergy", "getMaxEnergy", "getLastInput", "getLastOutput", "getTransferCap" }) then
            return peripheral.wrap(name), name
        end
    end
end

local function findEnergyDetector()
    for _, name in ipairs(peripheral.getNames()) do
        local ptype = peripheral.getType(name)
        if peripheral.hasType(name, "energy_detector") or ptype == "energy_detector" then
            return peripheral.wrap(name), name
        end
    end
end

local function readFlux()
    local flux, fluxName = findFluxDevice()
    if not flux then return nil end

    local valid = call(flux, "isValid", true)
    local networkName = call(flux, "getNetworkName", "UNKNOWN")
    local networkId = call(flux, "getNetworkID", nil)
    local stored = call(flux, "getEnergy", nil)
    local capacity = call(flux, "getEnergyCapacity", nil)
    local input = call(flux, "getEnergyInput", nil)
    local output = call(flux, "getEnergyOutput", nil)
    local buffer = call(flux, "getEnergyBuffer", nil)
    local plugs = call(flux, "getPlugsCount", nil)
    local points = call(flux, "getPointCount", nil)
    local storages = call(flux, "getStorageCount", nil)
    local controllers = call(flux, "getControllerCount", nil)
    local avgTickUs = call(flux, "getAVGTickUs", nil)
    local security = call(flux, "getSecurityLevel", nil)

    local filled
    if type(stored) == "number" and type(capacity) == "number" and capacity > 0 then
        filled = stored / capacity
    end

    return {
        sourceType = "flux_network",
        peripheral = fluxName,
        networkName = networkName,
        networkId = networkId,
        stored = stored,
        capacity = capacity,
        input = input,
        output = output,
        buffer = buffer,
        plugs = plugs,
        points = points,
        storages = storages,
        controllers = controllers,
        avgTickUs = avgTickUs,
        security = security,
        filledPercentage = filled,
        net = (type(input) == "number" and type(output) == "number") and (input - output) or nil,
        status = valid == false and "DEGRADED" or "ONLINE",
        _status = valid == false and "degraded" or "online",
        _updated = os.epoch("utc")
    }
end

function M.read(previous)
    -- Prefer Flux when it is attached: this is the network-wide view we want on
    -- the KIMI ComputerCraft power screen. Matrix remains the fallback source.
    local flux = readFlux()
    if flux then return flux end

    local port, portName = findInductionPort()
    if port then
        local energy = call(port, "getEnergy", nil)
        local maxEnergy = call(port, "getMaxEnergy", nil)
        local input = call(port, "getLastInput", nil)
        local output = call(port, "getLastOutput", nil)
        local transferCap = call(port, "getTransferCap", nil)
        local filled = call(port, "getEnergyFilledPercentage", nil)
        local needed = call(port, "getEnergyNeeded", nil)
        local installedCells = call(port, "getInstalledCells", nil)
        local mode = call(port, "getMode", nil)
        local comparator = call(port, "getComparatorLevel", nil)

        return {
            sourceType = "mekanism_induction_port",
            peripheral = portName,
            stored = energy,
            capacity = maxEnergy,
            input = input,
            output = output,
            transferCap = transferCap,
            filledPercentage = filled,
            energyNeeded = needed,
            installedCells = installedCells,
            mode = mode,
            comparatorLevel = comparator,
            net = (type(input) == "number" and type(output) == "number") and (input - output) or nil,
            status = "ONLINE",
            _status = "online",
            _updated = os.epoch("utc")
        }
    end

    local detector, detectorName = findEnergyDetector()
    if detector then
        local transferRate = call(detector, "getTransferRate", nil)
        return {
            sourceType = "energy_detector",
            peripheral = detectorName,
            transferRate = transferRate,
            transferRateLimit = call(detector, "getTransferRateLimit", nil),
            maxTransferRate = call(detector, "getMaxTransferRate", nil),
            input = transferRate,
            output = transferRate,
            status = "ONLINE",
            _status = "online",
            _updated = os.epoch("utc")
        }
    end

    return {
        sourceType = nil,
        peripheral = nil,
        stored = nil,
        capacity = nil,
        input = nil,
        output = nil,
        status = "OFFLINE",
        _status = "offline",
        _updated = os.epoch("utc")
    }
end

return M
