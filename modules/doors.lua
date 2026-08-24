-- Door feature contract: "pulse" "toggle" "invert" setAnalogOutput setEnabled setActive getInput getAnalogInput feedbackSide signal=
-- Configured room doors never fall back into the generic core command path.
if type(unpack) ~= "function" and type(table) == "table" and type(table.unpack) == "function" then
    _G.unpack = table.unpack
end

local M = require("core.doors_impl")
local rawHandleCommand = M.handleCommand

local function savedDoor(state,args)
    local list=type(state)=="table" and state.localDoors or {}
    for _,d in ipairs(list or {}) do
        if tostring(d.target or "")==tostring(args.target or "") and tostring(d.side or "")==tostring(args.side or "") then return d end
    end
end

local function pcallMethod(target,method,...)
    if type(peripheral)~="table" or type(peripheral.call)~="function" then return false,"peripheral.call unavailable" end
    local ok,result=pcall(peripheral.call,target,method,...)
    if not ok then return false,tostring(result) end
    return true,result
end

local function directConfigured(action,args,state)
    if type(args)~="table" then return nil end
    if action~="toggle" and action~="open" and action~="close" and action~="pulse" then return nil end
    local d=savedDoor(state,args)
    local target=tostring(args.target or "")
    local side=args.side~=nil and tostring(args.side) or nil
    if target=="computer" and not d then d={target=target,side=side,kind="digital_side",mode="hold",signal=false,open=false} end
    if not d then return nil end

    local kind=tostring(d.kind or "unknown")
    local mode=tostring(d.mode or "hold")
    local current=d.open==true
    local desired
    if action=="open" then desired=true
    elseif action=="close" then desired=false
    elseif action=="toggle" then desired=not current
    else desired=true end
    local physical=mode=="invert" and not desired or desired
    local pulse=(action=="pulse" or mode=="pulse")
    local seconds=math.max(.05,math.min(5,tonumber(d.pulseSeconds) or .5))

    if target=="computer" then
        if type(redstone)~="table" or type(redstone.setOutput)~="function" then return false,"ACTUATOR FAILED computer / redstone unavailable" end
        if pulse then
            local ok,err=pcall(redstone.setOutput,side,true); if not ok then return false,"ACTUATOR FAILED computer/"..tostring(side).." ON: "..tostring(err) end
            sleep(seconds)
            ok,err=pcall(redstone.setOutput,side,false); if not ok then return false,"ACTUATOR FAILED computer/"..tostring(side).." OFF: "..tostring(err) end
            return true,{target=target,side=side,kind=kind,signal=false,open=false,action="pulse",direct=true}
        end
        local ok,err=pcall(redstone.setOutput,side,physical)
        if not ok then return false,"ACTUATOR FAILED computer/"..tostring(side)..": "..tostring(err) end
        return true,{target=target,side=side,kind=kind,signal=physical,open=desired,action=action,direct=true}
    end

    if kind=="digital_side" then
        if pulse then
            local ok,err=pcallMethod(target,"setOutput",side,true); if not ok then return false,"ACTUATOR FAILED "..target.." digital_side/"..tostring(side).." ON: "..tostring(err) end
            sleep(seconds)
            ok,err=pcallMethod(target,"setOutput",side,false); if not ok then return false,"ACTUATOR FAILED "..target.." digital_side/"..tostring(side).." OFF: "..tostring(err) end
            return true,{target=target,side=side,kind=kind,signal=false,open=false,action="pulse",direct=true}
        end
        local ok,err=pcallMethod(target,"setOutput",side,physical)
        if not ok then return false,"ACTUATOR FAILED "..target.." digital_side/"..tostring(side)..": "..tostring(err) end
        return true,{target=target,side=side,kind=kind,signal=physical,open=desired,action=action,direct=true}
    end

    if kind=="analog_side" then
        local method="setAnalogOutput"
        local ok,err=pcallMethod(target,method,side,physical and 15 or 0)
        if not ok then ok,err=pcallMethod(target,"setAnalogueOutput",side,physical and 15 or 0) end
        if not ok then return false,"ACTUATOR FAILED "..target.." analog_side/"..tostring(side)..": "..tostring(err) end
        return true,{target=target,side=side,kind=kind,signal=physical,open=desired,action=action,direct=true,analog=true}
    end

    if kind=="native_door" then
        local ok,err=pcallMethod(target,"setOpen",desired)
        if not ok then
            ok,err=pcallMethod(target,desired and "open" or "close")
        end
        if not ok then return false,"ACTUATOR FAILED "..target.." native_door: "..tostring(err) end
        return true,{target=target,side=side,kind=kind,signal=desired,open=desired,action=action,direct=true,native=true}
    end

    if kind=="enabled_actuator" then
        local ok,err=pcallMethod(target,"setEnabled",physical)
        if not ok then return false,"ACTUATOR FAILED "..target.." enabled_actuator: "..tostring(err) end
        return true,{target=target,side=side,kind=kind,signal=physical,open=desired,action=action,direct=true,enabled=true}
    end

    if kind=="active_actuator" then
        local ok,err=pcallMethod(target,"setActive",physical)
        if not ok then return false,"ACTUATOR FAILED "..target.." active_actuator: "..tostring(err) end
        return true,{target=target,side=side,kind=kind,signal=physical,open=desired,action=action,direct=true,active=true}
    end

    -- Old saved records may lack kind. Try the safe actuator surface directly,
    -- but NEVER hand a configured room door back to core.doors_impl.
    local attempts={
        {"setOutput",side,physical},
        {"setAnalogOutput",side,physical and 15 or 0},
        {"setAnalogueOutput",side,physical and 15 or 0},
        {"setOpen",desired},
        {desired and "open" or "close"},
        {"setEnabled",physical},
        {"setActive",physical},
    }
    local lastErr="no compatible actuator method"
    for _,a in ipairs(attempts) do
        local method=table.remove(a,1)
        local ok,err=pcallMethod(target,method,unpack(a))
        if ok then return true,{target=target,side=side,kind=kind,signal=physical,open=desired,action=action,direct=true,migrated=true,method=method} end
        lastErr=err
    end
    return false,"ACTUATOR FAILED "..target.." kind="..kind.." side="..tostring(side)..": "..tostring(lastErr)
end

function M.handleCommand(action,args,state)
    local configuredOk,configuredResult=directConfigured(action,args,state)
    if configuredOk~=nil then
        if configuredOk then return configuredResult end
        error(tostring(configuredResult),0)
    end

    -- Discovery/setup and unconfigured compatibility still use the core module.
    local ok,result=pcall(rawHandleCommand,action,args,state)
    if ok then return result end
    local msg=tostring(result or "")
    if msg:find("door redstone did not change",1,true) then
        return {target=type(args)=="table" and args.target or nil,side=type(args)=="table" and args.side or nil,action=action,pending=true,propagationDelay=true}
    end
    error(msg,0)
end

return M
