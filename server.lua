-- KIMI Base OS central server
local environment = require("lib.environment")
local network = require("lib.network")

network.host()

local state = {
    version = "0.5.0-alpha",
    serverId = os.getComputerID(),
    started = os.epoch("utc"),
    environment = environment.read(),
    system = {
        peripherals = #peripheral.getNames(),
        updated = os.epoch("utc")
    }
}

local function refreshState()
    state.environment = environment.read()
    state.system = {
        peripherals = #peripheral.getNames(),
        updated = os.epoch("utc")
    }
end

print("KIMI Base Server online")
print("Computer ID: " .. os.getComputerID())

local refreshTimer = os.startTimer(0.5)

while true do
    local event = { os.pullEvent() }

    if event[1] == "timer" and event[2] == refreshTimer then
        refreshState()
        refreshTimer = os.startTimer(0.5)

    elseif event[1] == "rednet_message" then
        local sender, message, protocol = event[2], event[3], event[4]
        if protocol == network.PROTOCOL and type(message) == "table" then
            if message.type == "get_state" then
                network.sendState(sender, state)
            elseif message.type == "ping" then
                rednet.send(sender, { type = "pong", serverId = os.getComputerID() }, network.PROTOCOL)
            end
        end

    elseif event[1] == "peripheral" or event[1] == "peripheral_detach" then
        refreshState()
    end
end
