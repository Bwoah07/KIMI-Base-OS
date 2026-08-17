local M = { id = "system" }

function M.read()
    return {
        computerId = os.getComputerID(),
        label = os.getComputerLabel(),
        peripherals = peripheral.getNames(),
        ingameTime = os.time("ingame"),
        ingameDay = os.day("ingame"),
        uptime = os.clock(),
        _updated = os.epoch("utc")
    }
end

return M
