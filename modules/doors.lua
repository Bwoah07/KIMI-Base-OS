local M = { id = "doors" }

local computerSides = { "top", "bottom", "left", "right", "front", "back" }
local worldSides = { "north", "south", "east", "west", "up", "down" }
local commandedStates = {}

local function safeCall(obj, method, fallback, ...)
    if not obj or type(obj[method]) ~= "function" then return fallback, false end
    local ok, value = pcall(obj[method], ...)
    if not ok then return fallback, false end
    return value, true
end

local function methods(name)
    local ok, value = pcall(peripheral.getMethods, name)
    local out = {}
    if ok and type(value) == "table" then
        for _, method in ipairs(value) do out[method] = true end
    end
    return out
end

local function peripheralType(name)
    local ok, value = pcall(peripheral.getType, name)
    return ok and tostring(value or "unknown") or "unknown"
end

local function redstoneChannels(getter, sides)
    local out = {}
    for _, side in ipairs(sides) do
        local value, ok = getter(side)
        out[#out + 1] = { side = side, open = ok and value == true or false, readable = ok }
    end
    return out
end

local function readControllers()
    local out = {}
    if type(redstone) == "table" and type(redstone.getOutput) == "function" and type(redstone.setOutput) == "function" then
        out[#out + 1] = {
            target = "computer",
            name = "Computer #" .. tostring(os.getComputerID()),
            type = "computer_redstone",
            kind = "redstone",
            channels = redstoneChannels(function(side)
                local ok, value = pcall(redstone.getOutput, side)
                return value, ok
            end, computerSides)
        }
    end

    local names = peripheral.getNames()
    table.sort(names)
    for _, name in ipairs(names) do
        local method = methods(name)
        local obj = peripheral.wrap(name)
        local ptype = peripheralType(name)
        if obj and method.getOutput and method.setOutput then
            out[#out + 1] = {
                target = name,
                name = name,
                type = ptype,
                kind = "redstone",
                channels = redstoneChannels(function(side)
                    return safeCall(obj, "getOutput", false, side)
                end, worldSides)
            }
        elseif obj and ((method.open and method.close) or method.setOpen) then
            local isOpen = commandedStates[name] == true
            if method.isOpen then isOpen = safeCall(obj, "isOpen", false) == true end
            out[#out + 1] = {
                target = name,
                name = name,
                type = ptype,
                kind = "door",
                channels = { { side = nil, label = "DOOR", open = isOpen, readable = method.isOpen == true } }
            }
        end
    end
    return out
end

local function allowed(value, list)
    for _, item in ipairs(list) do if item == value then return true end end
    return false
end

local function setRedstone(target, side, value)
    if target == "computer" then
        if not allowed(side, computerSides) then error("invalid computer redstone side") end
        redstone.setOutput(side, value)
        return true
    end

    if not peripheral.isPresent(target) then error("door controller is not attached") end
    local obj = peripheral.wrap(target)
    local method = methods(target)
    if not obj or not method.setOutput or not allowed(side, worldSides) then error("invalid redstone integrator target") end
    local _, ok = safeCall(obj, "setOutput", nil, side, value)
    if not ok then error("redstone integrator rejected output") end
    return true
end

local function readRedstone(target, side)
    if target == "computer" then return redstone.getOutput(side) == true end
    local obj = peripheral.wrap(target)
    local value, ok = safeCall(obj, "getOutput", false, side)
    return ok and value == true
end

local function setDoor(target, value)
    if not peripheral.isPresent(target) then error("door peripheral is not attached") end
    local obj = peripheral.wrap(target)
    local method = methods(target)
    if method.setOpen then
        local _, ok = safeCall(obj, "setOpen", nil, value)
        if not ok then error("door rejected setOpen") end
    elseif value and method.open then
        local _, ok = safeCall(obj, "open", nil)
        if not ok then error("door rejected open") end
    elseif not value and method.close then
        local _, ok = safeCall(obj, "close", nil)
        if not ok then error("door rejected close") end
    else
        error("door peripheral does not expose a safe open/close method")
    end
    commandedStates[target] = value
    return true
end

local function readDoor(target)
    local obj = peripheral.wrap(target)
    local value, ok = safeCall(obj, "isOpen", false)
    if ok then return value == true end
    return commandedStates[target] == true
end

function M.read()
    local controllers = readControllers()
    local channels = 0
    for _, controller in ipairs(controllers) do channels = channels + #(controller.channels or {}) end
    return {
        controllers = controllers,
        controllerCount = #controllers,
        channelCount = channels,
        _status = "online",
        _updated = os.epoch("utc")
    }
end

function M.handleCommand(action, args)
    args = type(args) == "table" and args or {}
    local target = tostring(args.target or "")
    local side = args.side and tostring(args.side) or nil
    if target == "" then error("door target is required") end
    if action ~= "open" and action ~= "close" and action ~= "toggle" and action ~= "pulse" then
        error("unsupported door action")
    end

    local method = target == "computer" and {} or methods(target)
    local isRedstone = target == "computer" or (method.getOutput and method.setOutput)
    local current = isRedstone and readRedstone(target, side) or readDoor(target)
    local desired = action == "open" or (action == "toggle" and not current) or action == "pulse"

    if isRedstone then setRedstone(target, side, desired) else setDoor(target, desired) end

    if action == "pulse" then
        local seconds = math.max(0.05, math.min(5, tonumber(args.seconds) or 1))
        sleep(seconds)
        if isRedstone then setRedstone(target, side, false) else setDoor(target, false) end
        desired = false
    end

    return { target = target, side = side, open = desired, action = action }
end

return M
