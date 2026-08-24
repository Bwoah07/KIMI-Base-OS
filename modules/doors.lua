local M = { id = "doors" }

local computerSides={"top","bottom","left","right","front","back"}
local worldSides={"north","south","east","west","up","down"}
local commandedStates={}
local ROOT=".kimi"
local LOCAL_PATH=ROOT.."/local_doors"

local function safeCall(obj,method,fallback,...)
    if not obj or type(obj[method])~="function" then return fallback,false end
    local ok,value=pcall(obj[method],...)
    if not ok then return fallback,false end
    return value,true
end
local function methods(name)
    local ok,value=pcall(peripheral.getMethods,name); local out={}
    if ok and type(value)=="table" then for _,m in ipairs(value) do out[m]=true end end
    return out
end
local function peripheralType(name)
    local raw={pcall(peripheral.getType,name)}; if not raw[1] then return "unknown" end
    return tostring(raw[2] or "unknown")
end
local function norm(v) return tostring(v or ""):lower():gsub("[^a-z0-9]","") end
local function localKey(target,side) return tostring(target or "").."|"..tostring(side or "") end
local function allowed(value,list) for _,item in ipairs(list) do if item==value then return true end end; return false end
local function isSideActuator(kind) return kind=="digital_side" or kind=="analog_side" end
local function supportsModes(kind) return kind~="native_door" end

local function readFile(path)
    if not fs.exists(path) or fs.isDir(path) then return nil end
    local f=fs.open(path,"r"); if not f then return nil end; local body=f.readAll(); f.close(); return body
end
local function normalizeMode(entry)
    local m=tostring(entry and entry.mode or "hold")
    if m~="hold" and m~="invert" and m~="pulse" then m="hold" end
    return m
end
local function loadLocalDoors()
    local raw=readFile(LOCAL_PATH); local value=raw and textutils.unserialize(raw) or nil
    if type(value)~="table" then return {} end
    local out={}
    for _,entry in ipairs(value) do
        if type(entry)=="table" and entry.target then
            entry.key=entry.key or localKey(entry.target,entry.side)
            entry.mode=normalizeMode(entry)
            entry.pulseSeconds=math.max(.05,math.min(5,tonumber(entry.pulseSeconds) or .5))
            out[#out+1]=entry
        end
    end
    return out
end
local function saveLocalDoors(entries)
    if not fs.exists(ROOT) then fs.makeDir(ROOT) end
    local f=assert(fs.open(LOCAL_PATH,"w")); f.write(textutils.serialize(entries or {})); f.close()
end

local function boolChannels(getter,sides)
    local out={}
    for _,side in ipairs(sides) do local value,ok=getter(side); out[#out+1]={side=side,label=side,signal=ok and value==true or false,readable=ok} end
    return out
end
local function analogChannels(getter,sides)
    local out={}
    for _,side in ipairs(sides) do local value,ok=getter(side); out[#out+1]={side=side,label=side,signal=ok and (tonumber(value) or 0)>0 or false,readable=ok} end
    return out
end
local function actuatorish(ptype)
    local n=norm(ptype)
    return n:find("redstone",1,true) or n:find("relay",1,true) or n:find("door",1,true) or n:find("gate",1,true) or n:find("piston",1,true) or n:find("switch",1,true)
end

local function readControllers()
    local out={}
    local names=peripheral.getNames(); table.sort(names)
    -- Purpose-built peripherals first. The computer's six generic redstone sides
    -- are fallback only, so room setup follows what the player actually built.
    for _,name in ipairs(names) do
        local method=methods(name); local obj=peripheral.wrap(name); local ptype=peripheralType(name)
        if obj and method.setOutput then
            out[#out+1]={target=name,name=name,type=ptype,kind="digital_side",priority=1,channels=boolChannels(function(side)
                if method.getOutput then return safeCall(obj,"getOutput",false,side) end
                return commandedStates[localKey(name,side)]==true,false
            end,worldSides)}
        elseif obj and (method.setAnalogOutput or method.setAnalogueOutput) then
            local setter=method.setAnalogOutput and "setAnalogOutput" or "setAnalogueOutput"
            local getter=method.getAnalogOutput and "getAnalogOutput" or (method.getAnalogueOutput and "getAnalogueOutput" or nil)
            out[#out+1]={target=name,name=name,type=ptype,kind="analog_side",priority=1,setter=setter,getter=getter,channels=analogChannels(function(side)
                if getter then return safeCall(obj,getter,0,side) end
                return commandedStates[localKey(name,side)] and 15 or 0,false
            end,worldSides)}
        elseif obj and ((method.open and method.close) or method.setOpen) then
            local state=commandedStates[name]==true; local readable=false
            if method.isOpen then state=safeCall(obj,"isOpen",false)==true; readable=true end
            out[#out+1]={target=name,name=name,type=ptype,kind="native_door",priority=0,channels={{side=nil,label="DOOR",signal=state,readable=readable}}}
        elseif obj and actuatorish(ptype) and (method.setEnabled or method.setActive) then
            local state=commandedStates[name]==true; local readable=false
            if method.isEnabled then state=safeCall(obj,"isEnabled",false)==true; readable=true
            elseif method.isActive then state=safeCall(obj,"isActive",false)==true; readable=true end
            out[#out+1]={target=name,name=name,type=ptype,kind=method.setEnabled and "enabled_actuator" or "active_actuator",priority=1,channels={{side=nil,label="ACTUATOR",signal=state,readable=readable}}}
        end
    end
    if type(redstone)=="table" and type(redstone.getOutput)=="function" and type(redstone.setOutput)=="function" then
        out[#out+1]={target="computer",name="THIS COMPUTER",type="computer_redstone",kind="digital_side",priority=9,channels=boolChannels(function(side)local ok,v=pcall(redstone.getOutput,side); return v,ok end,computerSides)}
    end
    table.sort(out,function(a,b) if (a.priority or 5)~=(b.priority or 5) then return (a.priority or 5)<(b.priority or 5) end; return tostring(a.target)<tostring(b.target) end)
    return out
end

local function setPhysical(target,side,controller,value)
    local kind=controller.kind
    if target=="computer" then
        if not allowed(side,computerSides) then error("invalid computer redstone side") end
        redstone.setOutput(side,value); commandedStates[localKey(target,side)]=value; return true
    end
    if not peripheral.isPresent(target) then error("door actuator is not attached") end
    local obj=peripheral.wrap(target); local method=methods(target)
    if kind=="digital_side" then
        if not method.setOutput or not allowed(side,worldSides) then error("invalid digital redstone actuator") end
        local _,ok=safeCall(obj,"setOutput",nil,side,value); if not ok then error("redstone actuator rejected output") end
    elseif kind=="analog_side" then
        local setter=method.setAnalogOutput and "setAnalogOutput" or (method.setAnalogueOutput and "setAnalogueOutput" or nil)
        if not setter or not allowed(side,worldSides) then error("invalid analog redstone actuator") end
        local _,ok=safeCall(obj,setter,nil,side,value and 15 or 0); if not ok then error("analog actuator rejected output") end
    elseif kind=="native_door" then
        local ok
        if method.setOpen then _,ok=safeCall(obj,"setOpen",nil,value)
        elseif value and method.open then _,ok=safeCall(obj,"open",nil)
        elseif (not value) and method.close then _,ok=safeCall(obj,"close",nil) end
        if not ok then error("door peripheral rejected open/close") end
    elseif kind=="enabled_actuator" and method.setEnabled then
        local _,ok=safeCall(obj,"setEnabled",nil,value); if not ok then error("actuator rejected setEnabled") end
    elseif kind=="active_actuator" and method.setActive then
        local _,ok=safeCall(obj,"setActive",nil,value); if not ok then error("actuator rejected setActive") end
    else error("unsupported door actuator") end
    commandedStates[side and localKey(target,side) or target]=value; return true
end

local function readPhysical(target,side,controller)
    if target=="computer" then return redstone.getOutput(side)==true,true end
    local obj=peripheral.wrap(target); if not obj then return false,false end; local method=methods(target); local kind=controller.kind
    if kind=="digital_side" and method.getOutput then local v,ok=safeCall(obj,"getOutput",false,side); if ok then return v==true,true end
    elseif kind=="analog_side" then local getter=method.getAnalogOutput and "getAnalogOutput" or (method.getAnalogueOutput and "getAnalogueOutput" or nil); if getter then local v,ok=safeCall(obj,getter,0,side); if ok then return (tonumber(v) or 0)>0,true end end
    elseif kind=="native_door" and method.isOpen then local v,ok=safeCall(obj,"isOpen",false); if ok then return v==true,true end
    elseif kind=="enabled_actuator" and method.isEnabled then local v,ok=safeCall(obj,"isEnabled",false); if ok then return v==true,true end
    elseif kind=="active_actuator" and method.isActive then local v,ok=safeCall(obj,"isActive",false); if ok then return v==true,true end end
    return commandedStates[side and localKey(target,side) or target]==true,false
end

local function logicalState(entry,controller,physical)
    local mode=normalizeMode(entry)
    if mode=="invert" and supportsModes(controller.kind) then return not physical end
    if mode=="pulse" then return commandedStates["logical:"..localKey(entry.target,entry.side)]==true end
    return physical
end

local function candidateList(controllers,localEntries)
    local byLocal={}; for _,entry in ipairs(localEntries or {}) do byLocal[entry.key or localKey(entry.target,entry.side)]=entry end
    local candidates,localDoors={},{}
    for _,controller in ipairs(controllers or {}) do
        for _,channel in ipairs(controller.channels or {}) do
            local key=localKey(controller.target,channel.side); local saved=byLocal[key]
            local candidate={target=controller.target,side=channel.side,label=channel.label or channel.side,controller=controller.name,type=controller.type,kind=controller.kind,priority=controller.priority,signal=channel.signal==true,open=channel.signal==true,readable=channel.readable==true,localKey=key,localConfigured=saved~=nil,localName=saved and saved.name or nil}
            candidates[#candidates+1]=candidate
            if saved then
                local logical=logicalState(saved,controller,channel.signal==true)
                localDoors[#localDoors+1]={id="local:"..key,key=key,name=saved.name or ((channel.label or channel.side or "LOCAL").." DOOR"),target=controller.target,side=channel.side,controller=controller.name,type=controller.type,kind=saved.kind or controller.kind,mode=normalizeMode(saved),pulseSeconds=tonumber(saved.pulseSeconds) or .5,open=logical,signal=channel.signal==true,readable=channel.readable==true,online=true,localConfigured=true,supportsModes=supportsModes(controller.kind)}
            end
        end
    end
    return candidates,localDoors
end

function M.read()
    local controllers=readControllers(); local localEntries=loadLocalDoors(); local candidates,localDoors=candidateList(controllers,localEntries)
    local channels=0; for _,c in ipairs(controllers) do channels=channels+#(c.channels or {}) end
    return {controllers=controllers,controllerCount=#controllers,candidates=candidates,candidateCount=#candidates,localDoors=localDoors,localDoorCount=#localDoors,channelCount=channels,_status="online",_updated=os.epoch("utc")}
end

local function findCandidate(target,side)
    for _,controller in ipairs(readControllers()) do
        if tostring(controller.target)==tostring(target) then
            for _,channel in ipairs(controller.channels or {}) do if tostring(channel.side or "")==tostring(side or "") then return controller,channel end end
        end
    end
end
local function findEntry(entries,target,side)
    local key=localKey(target,side)
    for i,e in ipairs(entries) do if (e.key or localKey(e.target,e.side))==key then return e,i end end
end

function M.handleCommand(action,args)
    args=type(args)=="table" and args or {}
    if action=="register_local" then
        local target=tostring(args.target or ""); local side=args.side and tostring(args.side) or nil
        if target=="" then error("local door target is required") end
        local controller,channel=findCandidate(target,side); if not controller or not channel then error("local door actuator is not attached") end
        local entries=loadLocalDoors(); local existing=findEntry(entries,target,side); if existing then return existing end
        local label=tostring(args.name or ""); if label=="" then local s=tostring(channel.label or side or "DOOR"):upper(); label=s=="DOOR" and "LOCAL DOOR" or (s.." DOOR") end
        local entry={key=localKey(target,side),name=label,target=target,side=side,kind=controller.kind,type=controller.type,mode="hold",pulseSeconds=.5}
        entries[#entries+1]=entry; saveLocalDoors(entries); return entry
    elseif action=="configure_local" then
        local target=tostring(args.target or ""); local side=args.side and tostring(args.side) or nil; local entries=loadLocalDoors(); local entry=findEntry(entries,target,side)
        if not entry then error("local door is not configured") end
        local controller=findCandidate(target,side); if not controller then error("door actuator is not attached") end
        local mode=tostring(args.mode or "hold"); if mode~="hold" and mode~="invert" and mode~="pulse" then error("invalid door mode") end
        if not supportsModes(controller.kind) and mode~="hold" then mode="hold" end
        entry.mode=mode; entry.pulseSeconds=math.max(.05,math.min(5,tonumber(args.pulseSeconds) or tonumber(entry.pulseSeconds) or .5)); saveLocalDoors(entries); return entry
    elseif action=="remove_local" then
        local target=tostring(args.target or ""); local side=args.side and tostring(args.side) or nil; local entries=loadLocalDoors(); local _,idx=findEntry(entries,target,side)
        if not idx then error("local door is not configured") end; local removed=table.remove(entries,idx); saveLocalDoors(entries); return removed
    end

    local target=tostring(args.target or ""); local side=args.side and tostring(args.side) or nil
    if target=="" then error("door target is required") end
    if action~="open" and action~="close" and action~="toggle" and action~="pulse" then error("unsupported door action") end
    local controller=findCandidate(target,side); if not controller then error("door actuator is not attached") end
    local entries=loadLocalDoors(); local entry=findEntry(entries,target,side) or {target=target,side=side,mode="hold",pulseSeconds=.5}
    local mode=normalizeMode(entry)

    if action=="pulse" or mode=="pulse" then
        local seconds=math.max(.05,math.min(5,tonumber(args.seconds) or tonumber(entry.pulseSeconds) or .5))
        setPhysical(target,side,controller,true); sleep(seconds); setPhysical(target,side,controller,false)
        local k="logical:"..localKey(target,side); commandedStates[k]=not (commandedStates[k]==true)
        return {target=target,side=side,kind=controller.kind,mode="pulse",open=commandedStates[k],action="pulse"}
    end

    local physical=readPhysical(target,side,controller); local current=logicalState(entry,controller,physical)
    local desired=action=="open" or (action=="toggle" and not current)
    local output=(mode=="invert" and supportsModes(controller.kind)) and (not desired) or desired
    setPhysical(target,side,controller,output)
    return {target=target,side=side,kind=controller.kind,mode=mode,open=desired,action=action}
end

return M
