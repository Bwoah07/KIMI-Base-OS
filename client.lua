-- KIMI Base OS client
local network = require("lib.network")

local function gameTime24()
    local t = os.time("ingame") % 24
    local h = math.floor(t)
    local m = math.floor((t - h) * 60)
    return string.format("%02d:%02d", h, m)
end

local function clearScreen()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
end

local function draw(state, connected)
    clearScreen()
    term.setTextColor(colors.red)
    print("KIMI BASE OS")
    term.setTextColor(colors.white)
    print("Client " .. os.getComputerID())
    print("")

    if not connected or not state then
        term.setTextColor(colors.yellow)
        print("Searching for base server...")
        return
    end

    term.setTextColor(colors.lime)
    print("SERVER ONLINE")
    term.setTextColor(colors.white)
    print("Time:    " .. gameTime24())

    local env = state.environment or {}
    print("Weather: " .. tostring(env.weather or "UNKNOWN"))
    print("Biome:   " .. tostring(env.biome or "UNKNOWN"))
    print("Moon:    " .. tostring(env.moon or "UNKNOWN"))
    print("Devices: " .. tostring((state.system or {}).peripherals or "?"))
    print("")
    term.setTextColor(colors.lightGray)
    print("Wall/pocket UI comes next.")
end

network.open()

local serverId = nil
local state = nil
local requestTimer = os.startTimer(0.1)
local staleTimer = nil

draw(nil, false)

while true do
    local event = { os.pullEvent() }

    if event[1] == "timer" and event[2] == requestTimer then
        if not serverId then
            serverId = rednet.lookup(network.PROTOCOL, network.SERVER_HOSTNAME)
        end

        if serverId then
            network.requestState(serverId)
        end

        requestTimer = os.startTimer(1)

    elseif event[1] == "rednet_message" then
        local sender, message, protocol = event[2], event[3], event[4]
        if protocol == network.PROTOCOL and sender == serverId and type(message) == "table" and message.type == "state" then
            state = message.payload
            draw(state, true)
        end

    elseif event[1] == "peripheral" or event[1] == "peripheral_detach" then
        network.open()
        serverId = rednet.lookup(network.PROTOCOL, network.SERVER_HOSTNAME)
    end
end
