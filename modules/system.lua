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

function M.handleCommand(action,args)
    if tostring(action or "") ~= "identify" then error("unsupported system action") end
    args=type(args)=="table"and args or{}
    local seconds=math.max(3,math.min(30,tonumber(args.duration)or 10))
    local now=os.epoch("utc")
    _G.kimiIdentifyUntil=now+seconds*1000
    _G.kimiIdentifyLabel=os.getComputerLabel()or("KIMI-"..tostring(os.getComputerID()))
    _G.kimiIdentifyId=os.getComputerID()
    term.setBackgroundColor(colors.black);term.setTextColor(colors.lime);term.clear();term.setCursorPos(1,1)
    print("========================")
    print("      KIMI IDENTIFY")
    print("========================")
    print("I AM: "..tostring(_G.kimiIdentifyLabel))
    print("ID:   "..tostring(_G.kimiIdentifyId))
    print("========================")
    local ok,speaker=pcall(peripheral.find,"speaker")
    if ok and speaker then pcall(speaker.playNote,"bell",3,12);pcall(speaker.playNote,"bell",3,18)end
    return{identified=true,id=_G.kimiIdentifyId,label=_G.kimiIdentifyLabel,seconds=seconds}
end

return M
