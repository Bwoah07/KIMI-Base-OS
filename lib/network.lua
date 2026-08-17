local M = {}

M.PROTOCOL = "kimi_base_os"
M.SERVER_HOSTNAME = "kimi-base"

local function openAllModems()
    local opened = false
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "modem") then
            local modem = peripheral.wrap(name)
            if modem and modem.isWireless and modem.isWireless() then
                rednet.open(name)
                opened = true
            end
        end
    end
    return opened
end

function M.open()
    return openAllModems()
end

function M.host()
    openAllModems()
    pcall(rednet.unhost, M.PROTOCOL)
    rednet.host(M.PROTOCOL, M.SERVER_HOSTNAME)
end

function M.findServer(timeout)
    openAllModems()
    local id = rednet.lookup(M.PROTOCOL, M.SERVER_HOSTNAME)
    if id then return id end

    local timer = os.startTimer(timeout or 3)
    while true do
        local event, a = os.pullEvent()
        if event == "timer" and a == timer then return nil end
        id = rednet.lookup(M.PROTOCOL, M.SERVER_HOSTNAME)
        if id then return id end
    end
end

function M.sendState(clientId, state)
    return rednet.send(clientId, {
        type = "state",
        payload = state
    }, M.PROTOCOL)
end

function M.requestState(serverId)
    rednet.send(serverId, { type = "get_state" }, M.PROTOCOL)
end

return M
