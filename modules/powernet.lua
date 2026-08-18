local M = { id = "powernet" }

local function hasMethod(name, method)
    local methods = peripheral.getMethods(name) or {}
    for _, m in ipairs(methods) do
        if m == method then return true end
    end
    return false
end

local function findPowerNet()
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "kimi_network_plug") or peripheral.getType(name) == "kimi_network_plug" then
            local p = peripheral.wrap(name)
            if p then return p, name end
        end
        if hasMethod(name, "listNetworks") and hasMethod(name, "listPlugs") then
            local p = peripheral.wrap(name)
            if p then return p, name end
        end
    end
end

local function safeCall(obj, method, fallback, ...)
    if not obj or type(obj[method]) ~= "function" then return fallback, false end
    local args = { ... }
    local ok, value = pcall(function() return obj[method](table.unpack(args)) end)
    if not ok or value == nil then return fallback, false end
    return value, true
end

local function collectType(typeName)
    local out = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, typeName) or peripheral.getType(name) == typeName then
            local p = peripheral.wrap(name)
            if p then
                local info = safeCall(p, "getInfo", {})
                if type(info) ~= "table" then info = {} end
                info.peripheral = name
                info.type = typeName
                out[#out + 1] = info
            end
        end
    end
    return out
end

local function sumNetworks(networks)
    local stored, capacity, input, output = 0, 0, 0, 0
    for _, n in ipairs(networks or {}) do
        stored = stored + (tonumber(n.stored) or 0)
        capacity = capacity + (tonumber(n.capacity) or 0)
        input = input + (tonumber(n.input) or 0)
        output = output + (tonumber(n.output) or 0)
    end
    return stored, capacity, input, output
end

function M.read(previous)
    local bridge, name = findPowerNet()
    local chargers = collectType("kimi_wireless_charger")
    local chunkLoaders = collectType("kimi_chunk_loader")

    if not bridge then
        return {
            sourceType = "kimi_powernet",
            peripheral = nil,
            networks = {},
            plugs = {},
            chargers = chargers,
            chunkLoaders = chunkLoaders,
            networkCount = 0,
            plugCount = 0,
            chargerCount = #chargers,
            chunkLoaderCount = #chunkLoaders,
            status = (#chargers > 0 or #chunkLoaders > 0) and "DEGRADED" or "OFFLINE",
            _status = (#chargers > 0 or #chunkLoaders > 0) and "degraded" or "offline",
            _updated = os.epoch("utc")
        }
    end

    local networks = safeCall(bridge, "listNetworks", {})
    local plugs = safeCall(bridge, "listPlugs", {})
    local info = safeCall(bridge, "getInfo", {})
    local version = safeCall(bridge, "getVersion", nil)
    local stored, capacity, input, output = sumNetworks(networks)

    return {
        sourceType = "kimi_powernet",
        peripheral = name,
        version = version,
        networks = networks,
        plugs = plugs,
        chargers = chargers,
        chunkLoaders = chunkLoaders,
        networkCount = #networks,
        plugCount = #plugs,
        chargerCount = #chargers,
        chunkLoaderCount = #chunkLoaders,
        totalStored = stored,
        totalCapacity = capacity,
        totalInput = input,
        totalOutput = output,
        net = input - output,
        localPlug = info,
        status = "ONLINE",
        _status = "online",
        _updated = os.epoch("utc")
    }
end

local function wrapNamed(name)
    if type(name) ~= "string" or name == "" then return nil end
    return peripheral.wrap(name)
end

function M.command(action, args)
    args = args or {}
    local bridge = findPowerNet()

    if action == "charger_set_network" or action == "charger_set_range" or action == "charger_set_rate" or action == "charger_set_target" then
        local p = wrapNamed(args.peripheral)
        if not p then return false, "charger peripheral offline" end
        if action == "charger_set_network" then return safeCall(p, "setNetwork", false, tostring(args.network or "BASE_POWER")) end
        if action == "charger_set_range" then return safeCall(p, "setRange", false, tonumber(args.range) or 32) end
        if action == "charger_set_rate" then return safeCall(p, "setChargeRate", false, tonumber(args.rate) or 512000000) end
        return safeCall(p, "setTargetEnabled", false, tostring(args.target or "inventory"), args.enabled ~= false)
    elseif action == "chunkloader_set_enabled" then
        local p = wrapNamed(args.peripheral)
        if not p then return false, "chunk loader peripheral offline" end
        return safeCall(p, "setEnabled", false, args.enabled ~= false)
    end

    if not bridge then return false, "powernet peripheral offline" end

    if action == "set_mode" then
        return safeCall(bridge, "setPlugMode", false, tostring(args.plugId or ""), tostring(args.mode or "DISABLED"))
    elseif action == "set_network" then
        return safeCall(bridge, "setPlugNetwork", false, tostring(args.plugId or ""), tostring(args.network or "BASE_POWER"))
    elseif action == "set_limit" then
        return safeCall(bridge, "setPlugTransferLimit", false, tostring(args.plugId or ""), tonumber(args.limit) or 512000000)
    elseif action == "disable_network" then
        return safeCall(bridge, "disableNetwork", 0, tostring(args.network or "BASE_POWER"))
    elseif action == "get_network" then
        return safeCall(bridge, "getNetwork", nil, tostring(args.network or "BASE_POWER"))
    elseif action == "list_networks" then
        return safeCall(bridge, "listNetworks", {})
    elseif action == "list_plugs" then
        return safeCall(bridge, "listPlugs", {})
    elseif action == "list_chargers" then
        return collectType("kimi_wireless_charger"), true
    elseif action == "list_chunk_loaders" then
        return collectType("kimi_chunk_loader"), true
    end

    return false, "unknown powernet action"
end

return M
