local M = { id = "ae2" }

local function findBridge()
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "me_bridge") or peripheral.getType(name) == "me_bridge" then
            return peripheral.wrap(name), name
        end
    end
end

local function call(obj, method, fallback, ...)
    if not obj or type(obj[method]) ~= "function" then return fallback, false end
    local ok, value = pcall(obj[method], ...)
    if not ok or value == nil then return fallback, false end
    return value, true
end

local function listCount(obj, method)
    local value, ok = call(obj, method, nil, {})
    if not ok then value, ok = call(obj, method, nil) end
    if not ok or type(value) ~= "table" then return nil end
    local n = 0
    for _ in pairs(value) do n = n + 1 end
    return n
end

function M.read(previous)
    local bridge, name = findBridge()
    local out = {
        bridge = name,
        online = false,
        connected = false,
        storedEnergy = nil,
        energyCapacity = nil,
        energyUsage = nil,
        avgPowerInjection = nil,
        usedItemStorage = nil,
        totalItemStorage = nil,
        availableItemStorage = nil,
        itemTypes = nil,
        craftingJobs = nil,
        _updated = os.epoch("utc")
    }

    if not bridge then
        out._status = "offline"
        return out
    end

    out.connected = call(bridge, "isConnected", false)
    out.online = call(bridge, "isOnline", out.connected)
    out.storedEnergy = call(bridge, "getStoredEnergy", nil)
    out.energyCapacity = call(bridge, "getEnergyCapacity", nil)
    out.energyUsage = call(bridge, "getEnergyUsage", nil)
    out.avgPowerInjection = call(bridge, "getAvgPowerInjection", nil)

    out.usedItemStorage = call(bridge, "getUsedItemStorage", nil)
    if out.usedItemStorage == nil then out.usedItemStorage = call(bridge, "getUsedExternItemStorage", nil) end

    out.totalItemStorage = call(bridge, "getMaxItemStorage", nil)
    if out.totalItemStorage == nil then out.totalItemStorage = call(bridge, "getTotalItemStorage", nil) end

    out.availableItemStorage = call(bridge, "getAvailableItemStorage", nil)
    out.itemTypes = listCount(bridge, "getItems") or listCount(bridge, "listItems")
    out.craftingJobs = listCount(bridge, "getCraftingTasks")

    out.items = out.usedItemStorage
    out.itemCount = out.itemTypes
    out._status = out.online and "online" or (out.connected and "offline" or "disconnected")
    return out
end

return M
