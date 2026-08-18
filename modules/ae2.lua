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

local function getItems(bridge)
    local items, ok = call(bridge, "getItems", nil, {})
    if not ok then items, ok = call(bridge, "getItems", nil) end
    if not ok then items, ok = call(bridge, "listItems", nil) end
    if not ok or type(items) ~= "table" then return nil end
    return items
end

local function summarizeItems(items)
    if type(items) ~= "table" then return nil, nil end
    local types, total = 0, 0
    for _, item in pairs(items) do
        if type(item) == "table" then
            types = types + 1
            local qty = tonumber(item.amount or item.count or item.size or item.qty or item.quantity)
            if qty then total = total + qty end
        end
    end
    return total, types
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
        items = nil,
        itemCount = nil,
        itemTypes = nil,
        craftingJobs = nil,
        _updated = os.epoch("utc")
    }

    if not bridge then out._status = "offline"; return out end

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

    local items = getItems(bridge)
    local total, types = summarizeItems(items)
    out.items = total
    out.itemCount = total
    out.itemTypes = types
    out.craftingJobs = listCount(bridge, "getCraftingTasks")
    out._status = out.online and "online" or (out.connected and "offline" or "disconnected")
    return out
end

return M
