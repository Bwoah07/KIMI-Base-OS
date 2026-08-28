local M = { id = "doors" }
local unpack=table.unpack or unpack
local ROOT = ".kimi"
local LOCAL_PATH = ROOT .. "/local_doors"
local relativeSides = {"top","bottom","left","right","front","back"}
local cardinalSides = {"north","south","east","west","up","down"}

local function key(target, side) return tostring(target or "") .. "|" .. tostring(side or "") end
local function has(list, value) for _,v in ipairs(list or {}) do if v==value then return true end end return false end
local function hasFs() return type(fs)=="table" and type(fs.exists)=="function" and type(fs.open)=="function" end
local function ensureRoot() if not hasFs() then return false end; if not fs.exists(ROOT) then fs.makeDir(ROOT) end; return true end
local function normalizeMode(v) v=tostring(v or "hold"); if v~="hold" and v~="invert" and v~="pulse" then v="hold" end; return v end

local function loadDoors()
    if not hasFs() then return {} end
    if not fs.exists(LOCAL_PATH) or fs.isDir(LOCAL_PATH) then return {} end
    local f=fs.open(LOCAL_PATH,"r"); if not f then return {} end
    local raw=f.readAll(); f.close()
    local parsed=textutils.unserialize(raw); if type(parsed)~="table" then return {} end
    local out={}
    for _,d in ipairs(parsed) do
        if type(d)=="table" and d.target then
            d.key=d.key or key(d.target,d.side)
            d.mode=normalizeMode(d.mode)
            d.pulseSeconds=math.max(.05,math.min(5,tonumber(d.pulseSeconds) or .5))
            out[#out+1]=d
        end
    end
    return out
end

local function saveDoors(v)
    if not ensureRoot() then return false end
    local tmp=LOCAL_PATH..".tmp"
    local f=assert(fs.open(tmp,"w")); f.write(textutils.serialize(v or {})); f.close()
    if fs.exists(LOCAL_PATH) and not fs.isDir(LOCAL_PATH) then fs.delete(LOCAL_PATH) end
    fs.move(tmp,LOCAL_PATH)
    return true
end

local function methods(name)
    local out={}
    if not peripheral or type(peripheral.getMethods)~="function" then return out end
    local ok,list=pcall(peripheral.getMethods,name)
    if ok and type(list)=="table" then for _,m in ipairs(list) do out[m]=true end end
    return out
end

local function ptype(name)
    local ok,v=pcall(peripheral.getType,name); if not ok then return "unknown" end
    if type(v)=="table" then return tostring(v[1] or "unknown") end
    return tostring(v or "unknown")
end

local function normalizedType(v)
    return tostring(v or ""):lower():gsub("[^%w]","")
end

local function pcallPeripheral(name, method, ...)
    local args={...}
    if type(peripheral)~="table" then return false,"peripheral API unavailable" end
    local ok,value
    if type(peripheral.call)=="function" then
        ok,value=pcall(function() return peripheral.call(name,method,unpack(args)) end)
    elseif type(peripheral.wrap)=="function" then
        local wrappedOk,wrapped=pcall(peripheral.wrap,name); local fn=wrappedOk and wrapped and wrapped[method]
        if type(fn)~="function" then return false,"peripheral method unavailable" end
        ok,value=pcall(fn,unpack(args))
    else
        return false,"peripheral.call unavailable"
    end
    if not ok then return false,tostring(value) end
    return true,value
end

local function computerOutput(side)
    if not has(relativeSides,side) then return false,false end
    local ok,v=pcall(redstone.getOutput,side); return ok and v==true,ok
end
local function computerInput(side)
    if not has(relativeSides,side) then return false,false end
    local ok,v=pcall(redstone.getInput,side); return ok and v==true,ok
end

local function peripheralOutput(name,m,side)
    if m.getOutput then local ok,v=pcallPeripheral(name,"getOutput",side); if ok then return v==true,true end end
    if m.getAnalogOutput then local ok,v=pcallPeripheral(name,"getAnalogOutput",side); if ok then return (tonumber(v) or 0)>0,true end end
    if m.getAnalogueOutput then local ok,v=pcallPeripheral(name,"getAnalogueOutput",side); if ok then return (tonumber(v) or 0)>0,true end end
    return false,false
end
local function peripheralInput(name,m,side)
    if m.getInput then local ok,v=pcallPeripheral(name,"getInput",side); if ok then return v==true,true end end
    if m.getAnalogInput then local ok,v=pcallPeripheral(name,"getAnalogInput",side); if ok then return (tonumber(v) or 0)>0,true end end
    if m.getAnalogueInput then local ok,v=pcallPeripheral(name,"getAnalogueInput",side); if ok then return (tonumber(v) or 0)>0,true end end
    return false,false
end

local function classify(name)
    local m=methods(name); local typ=ptype(name)
    if m.setOutput then return {target=name,name=name,type=typ,kind="digital_side",priority=1,methods=m} end
    if m.setAnalogOutput or m.setAnalogueOutput then return {target=name,name=name,type=typ,kind="analog_side",priority=1,methods=m} end
    if m.setOpen or (m.open and m.close) then return {target=name,name=name,type=typ,kind="native_door",priority=0,methods=m} end
    if m.setEnabled then return {target=name,name=name,type=typ,kind="enabled_actuator",priority=2,methods=m} end
    if m.setActive then return {target=name,name=name,type=typ,kind="active_actuator",priority=2,methods=m} end
end

local function controllerSides(c)
    if not c or (c.kind~="digital_side" and c.kind~="analog_side") then return {} end
    local typ=normalizedType(c.type)
    -- CC:Tweaked Redstone Relay is computer-relative only. Advanced
    -- Peripherals' Redstone Integrator accepts relative sides too, so prefer
    -- one stable vocabulary for both common KIMI door controllers.
    if typ=="redstonerelay" or typ=="redstoneintegrator" then return relativeSides end
    -- Preserve compatibility for older/other actuator peripherals which KIMI
    -- historically addressed with world/cardinal directions.
    return cardinalSides
end

local function controllers()
    local out={}
    if peripheral and type(peripheral.getNames)=="function" then
        local ok,names=pcall(peripheral.getNames)
        if ok and type(names)=="table" then
            table.sort(names)
            for _,name in ipairs(names) do
                local c=classify(name)
                if c then
                    c.channels={}
                    if c.kind=="digital_side" or c.kind=="analog_side" then
                        c.sideModel=(controllerSides(c)==relativeSides) and "relative" or "cardinal"
                        for _,side in ipairs(controllerSides(c)) do
                            local o,orx=peripheralOutput(name,c.methods,side)
                            local i,ir=peripheralInput(name,c.methods,side)
                            c.channels[#c.channels+1]={side=side,label=side,signal=o,readable=orx,input=i,inputReadable=ir}
                        end
                    else
                        local signal,readable=false,false
                        if c.methods.isOpen then readable,signal=pcallPeripheral(name,"isOpen")
                        elseif c.methods.isEnabled then readable,signal=pcallPeripheral(name,"isEnabled")
                        elseif c.methods.isActive then readable,signal=pcallPeripheral(name,"isActive") end
                        c.channels[1]={side=nil,label="DOOR",signal=signal==true,readable=readable==true,input=signal==true,inputReadable=readable==true}
                    end
                    out[#out+1]=c
                end
            end
        end
    end
    if type(redstone)=="table" and type(redstone.setOutput)=="function" then
        local c={target="computer",name="THIS COMPUTER",type="computer_redstone",kind="digital_side",priority=9,sideModel="relative",channels={}}
        for _,side in ipairs(relativeSides) do
            local o,orx=computerOutput(side); local i,ir=computerInput(side)
            c.channels[#c.channels+1]={side=side,label=side,signal=o,readable=orx,input=i,inputReadable=ir}
        end
        out[#out+1]=c
    end
    table.sort(out,function(a,b) if a.priority~=b.priority then return a.priority<b.priority end return tostring(a.target)<tostring(b.target) end)
    return out
end

local function findController(target)
    for _,c in ipairs(controllers()) do if tostring(c.target)==tostring(target) then return c end end
end
local function findChannel(c,side)
    if not c then return nil end
    for _,ch in ipairs(c.channels or {}) do if tostring(ch.side or "")==tostring(side or "") then return ch end end
end
local function findSaved(list,target,side)
    local k=key(target,side); for i,d in ipairs(list) do if (d.key or key(d.target,d.side))==k then return d,i end end
end

local function validSide(c,side)
    return has(controllerSides(c),side)
end

local function setActuator(c,side,value)
    if c.target=="computer" then
        if not has(relativeSides,side) then return false,"invalid computer redstone side" end
        local ok,err=pcall(redstone.setOutput,side,value==true); if not ok then return false,tostring(err) end; return true
    end
    local m=c.methods or methods(c.target)
    if c.kind=="digital_side" then
        if not validSide(c,side) then return false,"invalid redstone actuator side" end
        return pcallPeripheral(c.target,"setOutput",side,value==true)
    elseif c.kind=="analog_side" then
        if not validSide(c,side) then return false,"invalid analog actuator side" end
        local method=m.setAnalogOutput and "setAnalogOutput" or "setAnalogueOutput"
        return pcallPeripheral(c.target,method,side,value and 15 or 0)
    elseif c.kind=="native_door" then
        if m.setOpen then return pcallPeripheral(c.target,"setOpen",value==true) end
        if value and m.open then return pcallPeripheral(c.target,"open") end
        if not value and m.close then return pcallPeripheral(c.target,"close") end
        return false,"native door has no usable command"
    elseif c.kind=="enabled_actuator" then
        return pcallPeripheral(c.target,"setEnabled",value==true)
    elseif c.kind=="active_actuator" then
        return pcallPeripheral(c.target,"setActive",value==true)
    end
    return false,"unsupported door actuator"
end

local function readActuator(c,side)
    if c.target=="computer" then return computerOutput(side) end
    local m=c.methods or methods(c.target)
    if c.kind=="digital_side" or c.kind=="analog_side" then return peripheralOutput(c.target,m,side) end
    if c.kind=="native_door" and m.isOpen then local ok,v=pcallPeripheral(c.target,"isOpen"); return v==true,ok end
    if c.kind=="enabled_actuator" and m.isEnabled then local ok,v=pcallPeripheral(c.target,"isEnabled"); return v==true,ok end
    if c.kind=="active_actuator" and m.isActive then local ok,v=pcallPeripheral(c.target,"isActive"); return v==true,ok end
    return false,false
end

local function feedbackState(d,c)
    if not d or not d.feedbackSide then return nil,false end
    local side=tostring(d.feedbackSide); local value,ok
    if c.target=="computer" then value,ok=computerInput(side)
    else value,ok=peripheralInput(c.target,c.methods or methods(c.target),side) end
    if not ok then return nil,false end
    if d.feedbackInvert then value=not value end
    return value,true
end

local function logicalState(d,c,physical)
    local fb,ok=feedbackState(d,c); if ok then return fb,"feedback" end
    if normalizeMode(d and d.mode)=="invert" then return not physical,"output" end
    return physical,"output"
end

function M.read()
    local cs=controllers(); local saved=loadDoors(); local savedByKey={}
    for _,d in ipairs(saved) do savedByKey[d.key or key(d.target,d.side)]=d end
    local candidates,localDoors={},{}
    for _,c in ipairs(cs) do
        for _,ch in ipairs(c.channels or {}) do
            local k=key(c.target,ch.side); local d=savedByKey[k]
            candidates[#candidates+1]={target=c.target,side=ch.side,label=ch.label,controller=c.name,type=c.type,kind=c.kind,sideModel=c.sideModel,priority=c.priority,signal=ch.signal==true,readable=ch.readable==true,inputSignal=ch.input==true,inputReadable=ch.inputReadable==true,localKey=k,localConfigured=d~=nil,localName=d and d.name or nil}
            if d then
                local open,source=logicalState(d,c,ch.signal==true)
                localDoors[#localDoors+1]={id="local:"..k,key=k,name=d.name or "LOCAL DOOR",target=c.target,side=ch.side,controller=c.name,type=c.type,kind=c.kind,sideModel=c.sideModel,mode=normalizeMode(d.mode),pulseSeconds=d.pulseSeconds or .5,open=open,signal=ch.signal==true,inputSignal=ch.input==true,inputReadable=ch.inputReadable==true,stateSource=source,feedbackSide=d.feedbackSide,feedbackInvert=d.feedbackInvert==true,online=true,localConfigured=true,supportsModes=c.kind~="native_door"}
            end
        end
    end
    return {controllers=cs,controllerCount=#cs,candidates=candidates,candidateCount=#candidates,localDoors=localDoors,localDoorCount=#localDoors,channelCount=#localDoors,_status="online",_updated=os.epoch("utc")}
end

function M.handleCommand(action,args)
    args=type(args)=="table" and args or {}
    local target=tostring(args.target or ""); local side=args.side~=nil and tostring(args.side) or nil
    if action=="register_local" then
        if target=="" then error("local door target is required") end
        local c=findController(target); local ch=findChannel(c,side); if not c or not ch then error("local door actuator is not attached") end
        local saved=loadDoors(); local old=findSaved(saved,target,side); if old then return old end
        local name=tostring(args.name or ""); if name=="" then name="LOCAL DOOR" end
        local d={key=key(target,side),name=name,target=target,side=side,kind=c.kind,type=c.type,mode="hold",pulseSeconds=.5}
        saved[#saved+1]=d; saveDoors(saved); return d
    end
    if action=="configure_local" then
        local saved=loadDoors(); local d=findSaved(saved,target,side); if not d then error("local door is not configured") end
        d.mode=normalizeMode(args.mode or d.mode)
        d.pulseSeconds=math.max(.05,math.min(5,tonumber(args.pulseSeconds) or tonumber(d.pulseSeconds) or .5))
        if args.feedbackSide~=nil then local f=tostring(args.feedbackSide); d.feedbackSide=(f=="" or f=="none") and nil or f end
        if args.feedbackInvert~=nil then d.feedbackInvert=args.feedbackInvert==true end
        saveDoors(saved); return d
    end
    if action=="remove_local" then
        local saved=loadDoors(); local _,i=findSaved(saved,target,side); if not i then error("local door is not configured") end
        local old=table.remove(saved,i); saveDoors(saved); return old
    end
    if target=="" then error("door target is required") end
    local c=findController(target); if not c then error("door actuator is not attached") end
    local saved=loadDoors(); local d=findSaved(saved,target,side) or {target=target,side=side,mode="hold",pulseSeconds=.5}
    if action=="pulse" or normalizeMode(d.mode)=="pulse" then
        local ok,err=setActuator(c,side,true); if not ok then error("door ON failed: "..tostring(err)) end
        sleep(math.max(.05,math.min(5,tonumber(args.seconds) or tonumber(d.pulseSeconds) or .5)))
        ok,err=setActuator(c,side,false); if not ok then error("door OFF failed: "..tostring(err)) end
        return {target=target,side=side,mode="pulse",signal=false,action="pulse"}
    end
    if action~="open" and action~="close" and action~="toggle" then error("unsupported door action") end
    local physical=select(1,readActuator(c,side)); local current=select(1,logicalState(d,c,physical))
    local desired=action=="open" or (action=="toggle" and not current)
    local wantedPhysical=normalizeMode(d.mode)=="invert" and not desired or desired
    local ok,err=setActuator(c,side,wantedPhysical); if not ok then error("door command failed: "..tostring(err)) end
    local actual,readable=readActuator(c,side)
    if readable and actual~=wantedPhysical then error("door redstone did not change: wanted "..tostring(wantedPhysical).." got "..tostring(actual)) end
    return {target=target,side=side,kind=c.kind,mode=normalizeMode(d.mode),open=desired,signal=readable and actual or wantedPhysical,action=action}
end

return M
