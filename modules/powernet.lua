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
    if not bridge then
        return {
            sourceType = "kimi_network_plug",
            peripheral = nil,
            networks = {},
            plugs = {},
            networkCount = 0,
            plugCount = 0,
            status = "OFFLINE",
            _status = "offline",
            _updated = os.epoch("utc")
        }
    end

    local networks = safeCall(bridge, "listNetworks", {})
    local plugs = safeCall(bridge, "listPlugs", {})
    local info = safeCall(bridge, "getInfo", {})
    local version = safeCall(bridge, "getVersion", nil)
    local stored, capacity, input, output = sumNetworks(networks)

    return {
        sourceType = "kimi_network_plug",
        peripheral = name,
        version = version,
        networks = networks,
        plugs = plugs,
        networkCount = #networks,
        plugCount = #plugs,
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

function M.command(action, args)
    args = args or {}
    local bridge = findPowerNet()
    if not bridge then return false, "powernet peripheral offline" end

    if action == "set_mode" then
        return safeCall(bridge, "setPlugMode", false, tostring(args.plugId or ""), tostring(args.mode or "DISABLED"))
    elseif action == "set_network" then
        return safeCall(bridge, "setPlugNetwork", false, tostring(args.plugId or ""), tostring(args.network or "BASE_POWER"))
    elseif action == "set_limit" then
        return safeCall(bridge, "setPlugTransferLimit", false, tostring(args.plugId or ""), tonumber(args.limit) or 16000000)
    elseif action == "disable_network" then
        return safeCall(bridge, "disableNetwork", 0, tostring(args.network or "BASE_POWER"))
    elseif action == "get_network" then
        return safeCall(bridge, "getNetwork", nil, tostring(args.network or "BASE_POWER"))
    elseif action == "list_networks" then
        return safeCall(bridge, "listNetworks", {})
    elseif action == "list_plugs" then
        return safeCall(bridge, "listPlugs", {})
    end

    return false, "unknown powernet action"
end

return M
