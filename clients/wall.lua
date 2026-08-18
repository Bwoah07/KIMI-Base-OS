local M = {}

local cfg = nil
local monitors = { left = nil, center = nil, right = nil }
local monitorNames = { left = nil, center = nil, right = nil }
local lastSignature = nil
local CAL_PATH = ".kimi/monitors"

local function ensureDir(path)
    local dir = fs.getDir(path)
    if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
end

local function saveCalibration()
    ensureDir(CAL_PATH)
    local f = assert(fs.open(CAL_PATH, "w"))
    f.write(textutils.serialize(monitorNames))
    f.close()
end

local function loadCalibration()
    if not fs.exists(CAL_PATH) then return false end
    local f = fs.open(CAL_PATH, "r")
    if not f then return false end
    local raw = f.readAll(); f.close()
    local t = textutils.unserialize(raw)
    if type(t) ~= "table" then return false end
    for _, key in ipairs({"left","center","right"}) do
        if type(t[key]) ~= "string" or not peripheral.isPresent(t[key]) or not peripheral.hasType(t[key], "monitor") then
            return false
        end
    end
    monitorNames = t
    monitors.left = peripheral.wrap(t.left)
    monitors.center = peripheral.wrap(t.center)
    monitors.right = peripheral.wrap(t.right)
    return true
end

local function listMonitors()
    local out = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "monitor") then out[#out+1] = name end
    end
    table.sort(out)
    return out
end

local function setScale(mon, scale)
    if mon and mon.setTextScale then pcall(mon.setTextScale, scale) end
end

local function clear(mon, bg)
    if not mon then return end
    mon.setBackgroundColor(bg or colors.black)
    mon.setTextColor(colors.white)
    mon.clear()
    mon.setCursorPos(1,1)
end

local function center(mon, y, text, color)
    if not mon then return end
    local w = select(1, mon.getSize())
    text = tostring(text or "")
    local x = math.max(1, math.floor((w - #text) / 2) + 1)
    mon.setCursorPos(x, y)
    mon.setTextColor(color or colors.white)
    mon.write(text)
end

local function gameTime()
    local t = os.time("ingame") % 24
    local h = math.floor(t)
    local m = math.floor((t - h) * 60)
    return string.format("%02d:%02d", h, m)
end

local function calibrate()
    local names = listMonitors()
    if #names < 3 then
        term.clear(); term.setCursorPos(1,1)
        term.setTextColor(colors.red)
        print("KIMI WALL CLIENT")
        term.setTextColor(colors.white)
        print("Need 3 attached monitors; found " .. tostring(#names))
        return false
    end

    term.clear(); term.setCursorPos(1,1)
    term.setTextColor(colors.red)
    print("KIMI WALL MONITOR CALIBRATION")
    term.setTextColor(colors.white)
    print("Touch the LEFT monitor...")

    for _, name in ipairs(names) do
        local mon = peripheral.wrap(name)
        setScale(mon, 0.5)
        clear(mon, colors.black)
        center(mon, 2, "TOUCH ME", colors.red)
        center(mon, 4, name, colors.lightGray)
    end

    local _, leftName = os.pullEvent("monitor_touch")
    monitorNames.left = leftName
    term.clear(); term.setCursorPos(1,1)
    print("LEFT = " .. leftName)
    print("Now touch the RIGHT monitor...")

    local rightName
    repeat
        local _, name = os.pullEvent("monitor_touch")
        if name ~= leftName then rightName = name end
    until rightName
    monitorNames.right = rightName

    for _, name in ipairs(names) do
        if name ~= leftName and name ~= rightName then
            monitorNames.center = name
            break
        end
    end

    monitors.left = peripheral.wrap(monitorNames.left)
    monitors.center = peripheral.wrap(monitorNames.center)
    monitors.right = peripheral.wrap(monitorNames.right)
    saveCalibration()

    term.clear(); term.setCursorPos(1,1)
    print("Calibration saved:")
    print("LEFT   " .. tostring(monitorNames.left))
    print("CENTER " .. tostring(monitorNames.center))
    print("RIGHT  " .. tostring(monitorNames.right))
    sleep(1)
    return true
end

local function ensureMonitors()
    if loadCalibration() then return true end
    return calibrate()
end

local function drawSide(mon, title, lines)
    if not mon then return end
    setScale(mon, 0.5)
    clear(mon, colors.black)
    local w, h = mon.getSize()
    mon.setBackgroundColor(colors.red)
    mon.setTextColor(colors.white)
    mon.setCursorPos(1,1)
    mon.write(string.rep(" ", w))
    center(mon, 1, title, colors.white)
    mon.setBackgroundColor(colors.black)
    local y = 3
    for _, line in ipairs(lines) do
        if y <= h then
            mon.setCursorPos(2,y)
            mon.setTextColor(line.color or colors.white)
            mon.write(tostring(line.text or ""))
            y = y + 2
        end
    end
end

local function drawCenter(envelope, meta)
    local mon = monitors.center
    if not mon then return end
    setScale(mon, 0.5)
    clear(mon, colors.black)
    local w, h = mon.getSize()

    mon.setBackgroundColor(colors.red)
    mon.setTextColor(colors.white)
    mon.setCursorPos(1,1)
    mon.write(string.rep(" ", w))
    center(mon, 1, "KIMI BASE OS", colors.white)
    mon.setBackgroundColor(colors.black)

    center(mon, 3, gameTime(), colors.white)
    if not meta.connected or not envelope then
        center(mon, 6, "SEARCHING FOR SERVER", colors.yellow)
        center(mon, 8, "ID " .. tostring(os.getComputerID()), colors.lightGray)
        return
    end

    center(mon, 5, "SERVER ONLINE", colors.lime)
    local env = envelope.state and envelope.state.environment or nil
    local weather = env and env.weather or "UNKNOWN"
    local biome = env and env.biome or "UNKNOWN"
    local moon = env and env.moon or "UNKNOWN"

    center(mon, 8, "WEATHER", colors.lightGray)
    center(mon, 10, weather, weather == "SUNNY" and colors.lime or colors.white)
    center(mon, 13, "BIOME  " .. tostring(biome), colors.white)
    center(mon, 15, "MOON   " .. tostring(moon), colors.white)

    if h >= 20 then
        center(mon, h-2, "KIMI " .. tostring(envelope.version or "") .. "  SERVER " .. tostring(meta.serverId or "?"), colors.gray)
    end
end

function M.init(config)
    cfg = config
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear(); term.setCursorPos(1,1)
    print("KIMI Wall Client")
    ensureMonitors()
end

function M.render(envelope, meta)
    if not monitors.center or not monitors.left or not monitors.right then
        if not ensureMonitors() then return end
    end

    local env = envelope and envelope.state and envelope.state.environment or nil
    local signature = table.concat({
        tostring(meta.connected), tostring(meta.serverId), gameTime(),
        tostring(env and env.weather), tostring(env and env.biome), tostring(env and env.moon),
        tostring(envelope and envelope.version)
    }, "|")
    if signature == lastSignature then return end
    lastSignature = signature

    drawCenter(envelope, meta)

    local envStatus = env and env._status or (meta.connected and "UNKNOWN" or "OFFLINE")
    drawSide(monitors.left, "ENVIRONMENT", {
        { text = "Weather", color = colors.lightGray },
        { text = env and env.weather or "UNKNOWN", color = colors.white },
        { text = "Biome", color = colors.lightGray },
        { text = env and env.biome or "UNKNOWN", color = colors.white },
        { text = "Sensor " .. tostring(envStatus), color = envStatus == "online" and colors.lime or colors.yellow }
    })

    drawSide(monitors.right, "SYSTEM", {
        { text = meta.connected and "SERVER ONLINE" or "SERVER OFFLINE", color = meta.connected and colors.lime or colors.red },
        { text = "Server " .. tostring(meta.serverId or "---"), color = colors.white },
        { text = "Client " .. tostring(os.getComputerID()), color = colors.white },
        { text = gameTime(), color = colors.white }
    })
end

function M.onPeripheralChange()
    monitors = { left = nil, center = nil, right = nil }
    lastSignature = nil
end

function M.handleEvent(e)
    -- Future touch navigation/actions live here.
end

return M
