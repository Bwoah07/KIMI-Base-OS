local M = { id = "doors" }

local ROOT = ".kimi"
local LOCAL_PATH = ROOT .. "/local_doors"
local computerSides = { "top", "bottom", "left", "right", "front", "back" }
local worldSides = { "north", "south", "east", "west", "up", "down" }

local function key(target, side)
    return tostring(target or "") .. "|" .. tostring(side or "")
end

local function contains(list, value)
    for _, v in ipairs(list) do if v == value then return true end end
    return false
end

local function ensureRoot()
    if not fs.exists(ROOT) then fs.makeDir(ROOT) end
end

local function loadDoors()
    if not fs.exists(LOCAL_PATH) or fs.isDir(LOCAL_PATH) then return {} end
    local f = fs.open(LOCAL_PATH, "r")
    if not f then return {} end
    local raw = f.readAll()
    f.close()
    local parsed = textutils.unserialize(raw)
    if type(parsed) ~= "table" then return {} end
    local out = {}
    for _, d in ipairs(parsed) do
        if type(d) == "table" and d.target then
            d.key = d.key or key(d.target, d.side)
            d.mode = tostring(d.mode or "hold")
            if d.mode ~= "hold" and d.mode ~= "invert" and d.mode ~= "pulse" then d.mode = "hold" end
            d.pulseSeconds = math.max(0.05, math.min(5, tonumber(d.pulseSeconds) or 0.5))
            out[#out + 1] = d
        end
    end
    return out
end

local function saveDoors(doors)
    ensureRoot()
    local f = assert(fs.open(LOCAL_PATH, "w"))
    f.write(textutils.serialize(doors or {}))
    f.close()
end

local function methods(name)
    local out = {}
    if not peripheral or type(peripheral.getMethods) ~= "function" then return out end
    local ok, list = pcall(peripheral.getMethods, name)
    if ok and type(list) == "table" then
        for _, m in ipairs(list) do out[m] = true end
    end
    return out
end

local function ptype(name)
    local ok, value = pcall(peripheral.getType, name)
    if not ok then return "unknown" end
    if type(value) == "table" then return tostring(value[1] or "unknown") end
    return tostring(value or "unknown")
end

-- Deliberately use peripheral.call rather than methods on peripheral.wrap().
-- This avoids wrapper/metatable incompatibilities between CC:Tweaked peripherals.
local function callPeripheral(name, method, ...)
    if not peripheral or type(peripheral.call) ~= "function" then
        return false, "peripheral.call unavailable"
    end
    local args = { ... }
    local ok, value = pcall(function()
        return peripheral.call(name, method, unpack(args))
    end)
    if not ok then return false, tostring(value) end
    return true, value
end

local function computerRead(side)
    if not contains(computerSides, side) then return false, false end
    local ok, value = pcall(redstone.getOutput, side)
    return ok and value == true, ok
end

local function computerInput(side)
    if not contains(computerSides, side) then return false, false end
    local ok, value = pcall(redstone.getInput, side)
    return ok and value == true, ok
end

local function readPeripheralOutput(name, m, side)
    if m.getOutput then
        local ok, value = callPeripheral(name, "getOutput", side)
        if ok then return value == true, true end
    end
    if m.getAnalogOutput then
        local ok, value = callPeripheral(name, "getAnalogOutput", side)
        if ok then return (tonumber(value) or 0) > 0, true end
    end
    if m.getAnalogueOutput then
        local ok, value = callPeripheral(name, "getAnalogueOutput", side)
        if ok then return (tonumber(value) or 0) > 0, true end
    end
    return false, false
end

local function readPeripheralInput(name, m, side)
    if m.getInput then
        local ok, value = callPeripheral(name, "getInput", side)
        if ok then return value == true, true end
    end
    if m.getAnalogInput then
        local ok, value = callPeripheral(name, "getAnalogInput", side)
        if ok then return (tonumber(value) or 0) > 0, true end
    end
    if m.getAnalogueInput then
        local ok, value = callPeripheral(name, "getAnalogueInput", side)
        if ok then return (tonumber(value) or 0) > 0, true end
    end
    return false, false
end

local function classifyPeripheral(name)
    local m = methods(name)
    local typ = ptype(name)
    if m.setOutput then return { target=name, name=name, type=typ, kind="digital_side", priority=1, methods=m } end
    if m.setAnalogOutput or m.setAnalogueOutput then return { target=name, name=name, type=typ, kind="analog_side", priority=1, methods=m } end
    if m.setOpen or (m.open and m.close) then return { target=name, name=name, type=typ, kind="native_door", priority=0, methods=m } end
    if m.setEnabled then return { target=name, name=name, type=typ, kind="enabled_actuator", priority=2, methods=m } end
    if m.setActive then return { target=name, name=name, type=typ, kind="active_actuator", priority=2, methods=m } end
    return nil
end

local function controllers()
    local out = {}
    if peripheral and type(peripheral.getNames) == "function" then
        local ok, names = pcall(peripheral.getNames)
        if ok and type(names) == "table" then
            table.sort(names)
            for _, name in ipairs(names) do
                local c = classifyPeripheral(name)
                if c then
                    c.channels = {}
                    if c.kind == "digital_side" or c.kind == "analog_side" then
                        for _, side in ipairs(worldSides) do
                            local output, readable = readPeripheralOutput(name, c.methods, side)
                            local input, inputReadable = readPeripheralInput(name, c.methods, side)
                            c.channels[#c.channels + 1] = {
                                side=side, label=side, signal=output, readable=readable,
                                input=input, inputReadable=inputReadable,
                            }
                        end
                    else
                        local signal, readable = false, false
                        if c.methods.isOpen then readable, signal = callPeripheral(name, "isOpen")
                        elseif c.methods.isEnabled then readable, signal = callPeripheral(name, "isEnabled")
                        elseif c.methods.isActive then readable, signal = callPeripheral(name, "isActive") end
                        c.channels[1] = { side=nil, label="DOOR", signal=signal == true, readable=readable == true, input=signal == true, inputReadable=readable == true }
                    end
                    out[#out + 1] = c
                end
            end
        end
    end

    if type(redstone) == "table" and type(redstone.setOutput) == "function" then
        local c = { target="computer", name="THIS COMPUTER", type="computer_redstone", kind="digital_side", priority=9, channels={} }
        for _, side in ipairs(computerSides) do
            local output, readable = computerRead(side)
            local input, inputReadable = computerInput(side)
            c.channels[#c.channels + 1] = { side=side, label=side, signal=output, readable=readable, input=input, inputReadable=inputReadable }
        end
        out[#out + 1] = c
    end

    table.sort(out, function(a,b)
        if a.priority ~= b.priority then return a.priority < b.priority end
        return tostring(a.target) < tostring(b.target)
    end)
    return out
end

local function findController(target)
    for _, c in ipairs(controllers()) do if tostring(c.target) == tostring(target) then return c end end
end

local function findChannel(c, side)
    if not c then return nil end
    for _, ch in ipairs(c.channels or {}) do
        if tostring(ch.side or "") == tostring(side or "") then return ch end
    end
end

local function setActuator(c, side, value)
    if c.target == "computer" then
        if not contains(computerSides, side) then return false, "invalid computer redstone side" end
        local ok, err = pcall(redstone.setOutput, side, value == true)
        if not ok then return false, tostring(err) end
        return true
    end

    local m = c.methods or methods(c.target)
    if c.kind == "digital_side" then
        if not contains(worldSides, side) then return false, "invalid redstone actuator side" end
        local ok, err = callPeripheral(c.target, "setOutput", side, value == true)
        if not ok then return false, err end
        return true
    elseif c.kind == "analog_side" then
        if not contains(worldSides, side) then return false, "invalid analog actuator side" end
        local method = m.setAnalogOutput and "setAnalogOutput" or "setAnalogueOutput"
        local ok, err = callPeripheral(c.target, method, side, value and 15 or 0)
        if not ok then return false, err end
        return true
    elseif c.kind == "native_door" then
        if m.setOpen then return callPeripheral(c.target, "setOpen", value == true) end
        if value and m.open then return callPeripheral(c.target, "open") end
        if not value and m.close then return callPeripheral(c.target, "close") end
        return false, "native door has no usable command"
    elseif c.kind == "enabled_actuator" then
        return callPeripheral(c.target, "setEnabled", value == true)
    elseif c.kind == "active_actuator" then
        return callPeripheral(c.target, "setActive", value == true)
    end
    return false, "unsupported door actuator"
end

local function readActuator(c, side)
    if c.target == "computer" then return computerRead(side) end
    local m = c.methods or methods(c.target)
    if c.kind == "digital_side" or c.kind == "analog_side" then return readPeripheralOutput(c.target, m, side) end
    if c.kind == "native_door" and m.isOpen then local ok,v=callPeripheral(c.target,"isOpen"); return v==true,ok end
    if c.kind == "enabled_actuator" and m.isEnabled then local ok,v=callPeripheral(c.target,"isEnabled"); return v==true,ok end
    if c.kind == "active_actuator" and m.isActive then local ok,v=callPeripheral(c.target,"isActive"); return v==true,ok end
    return false, false
end

local function findSaved(list, target, side)
    local k = key(target, side)
    for i, d in ipairs(list) do if (d.key or key(d.target,d.side)) == k then return d, i end end
end

function M.read()
    local cs = controllers()
    local saved = loadDoors()
    local savedByKey = {}
    for _, d in ipairs(saved) do savedByKey[d.key or key(d.target,d.side)] = d end
    local candidates, localDoors = {}, {}

    for _, c in ipairs(cs) do
        for _, ch in ipairs(c.channels or {}) do
            local k = key(c.target, ch.side)
            local d = savedByKey[k]
            candidates[#candidates + 1] = {
                target=c.target, side=ch.side, label=ch.label, controller=c.name,
                type=c.type, kind=c.kind, priority=c.priority, signal=ch.signal == true,
                readable=ch.readable == true, inputSignal=ch.input == true,
                inputReadable=ch.inputReadable == true, localKey=k,
                localConfigured=d ~= nil, localName=d and d.name or nil,
            }
            if d then
                local physical = ch.signal == true
                local logical = d.mode == "invert" and not physical or physical
                localDoors[#localDoors + 1] = {
                    id="local:"..k, key=k, name=d.name or "LOCAL DOOR",
                    target=c.target, side=ch.side, controller=c.name, type=c.type, kind=c.kind,
                    mode=d.mode or "hold", pulseSeconds=d.pulseSeconds or 0.5,
                    open=logical, signal=physical, inputSignal=ch.input == true,
                    inputReadable=ch.inputReadable == true, online=true, localConfigured=true,
                    supportsModes=c.kind ~= "native_door",
                }
            end
        end
    end

    return {
        controllers=cs, controllerCount=#cs, candidates=candidates, candidateCount=#candidates,
        localDoors=localDoors, localDoorCount=#localDoors, _status="online", _updated=os.epoch("utc"),
    }
end

function M.handleCommand(action, args)
    args = type(args) == "table" and args or {}
    local target = tostring(args.target or "")
    local side = args.side ~= nil and tostring(args.side) or nil

    if action == "register_local" then
        if target == "" then error("local door target is required") end
        local c = findController(target)
        local ch = findChannel(c, side)
        if not c or not ch then error("local door actuator is not attached") end
        local saved = loadDoors()
        local old = findSaved(saved, target, side)
        if old then return old end
        local name = tostring(args.name or "")
        if name == "" then name = "LOCAL DOOR" end
        local d = { key=key(target,side), name=name, target=target, side=side, kind=c.kind, type=c.type, mode="hold", pulseSeconds=0.5 }
        saved[#saved + 1] = d
        saveDoors(saved)
        return d
    end

    if action == "configure_local" then
        local saved = loadDoors()
        local d = findSaved(saved, target, side)
        if not d then error("local door is not configured") end
        local mode = tostring(args.mode or d.mode or "hold")
        if mode ~= "hold" and mode ~= "invert" and mode ~= "pulse" then error("invalid door mode") end
        d.mode = mode
        d.pulseSeconds = math.max(0.05, math.min(5, tonumber(args.pulseSeconds) or tonumber(d.pulseSeconds) or 0.5))
        saveDoors(saved)
        return d
    end

    if action == "remove_local" then
        local saved = loadDoors()
        local _, idx = findSaved(saved, target, side)
        if not idx then error("local door is not configured") end
        local old = table.remove(saved, idx)
        saveDoors(saved)
        return old
    end

    if target == "" then error("door target is required") end
    local c = findController(target)
    if not c then error("door actuator is not attached") end
    local saved = loadDoors()
    local d = findSaved(saved, target, side) or { target=target, side=side, mode="hold", pulseSeconds=0.5 }

    if action == "pulse" or d.mode == "pulse" then
        local ok, err = setActuator(c, side, true)
        if not ok then error("door ON failed: " .. tostring(err)) end
        sleep(math.max(0.05, math.min(5, tonumber(args.seconds) or tonumber(d.pulseSeconds) or 0.5)))
        ok, err = setActuator(c, side, false)
        if not ok then error("door OFF failed: " .. tostring(err)) end
        return { target=target, side=side, mode="pulse", signal=false, action="pulse" }
    end

    if action ~= "open" and action ~= "close" and action ~= "toggle" then error("unsupported door action") end
    local physical = select(1, readActuator(c, side))
    local current = d.mode == "invert" and not physical or physical
    local desired = action == "open" or (action == "toggle" and not current)
    local wantedPhysical = d.mode == "invert" and not desired or desired
    local ok, err = setActuator(c, side, wantedPhysical)
    if not ok then error("door command failed: " .. tostring(err)) end

    local actual, readable = readActuator(c, side)
    if readable and actual ~= wantedPhysical then
        error("door redstone did not change: wanted " .. tostring(wantedPhysical) .. " got " .. tostring(actual))
    end
    return { target=target, side=side, kind=c.kind, mode=d.mode, open=desired, signal=readable and actual or wantedPhysical, action=action }
end

return M
