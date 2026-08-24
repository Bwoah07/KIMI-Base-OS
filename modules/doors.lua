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
    local ok,value=pcall(peripheral.getType,name); return ok and tostring(value or "unknown") or "unknown"
end
local function norm(v) return tostring(v or ""):lower():gsub("[^a-z0-9]","") end
local function localKey(target,side) return tostring(target or "").."|"..tostring(side or "") end
local function allowed(value,list) for _,item in ipairs(list) do if item==value then return true end end; return false end

local function readFile(path)
    if not fs.exists(path) or fs.isDir(path) then return nil end
    local f=fs.open(path,"r"); if not f then return nil end; local body=f.readAll(); f.close(); return body
end
local function loadLocalDoors()
    local raw=readFile(LOCAL_PATH); local value=raw and textutils.unserialize(raw) or nil
    if type(value)~="table" then return {} end
    local out={}
    for _,entry in ipairs(value) do if type(entry)=="table" and entry.target then entry.key=entry.key or localKey(entry.target,entry.side); out[#out+1]=entry end end
    return out
end
local function saveLocalDoors(entries)
    if not fs.exists(ROOT) then fs.makeDir(ROOT) end
    local f=assert(fs.open(LOCAL_PATH,"w")); f.write(textutils.serialize(entries or {})); f.close()
end

local function boolChannels(getter,sides)
    local out={}
    for _,side in ipairs(sides) do local value,ok=getter(side); out[#out+1]={side=side,label=side,open=ok and value==true or false,readable=ok} end
    return out
end
local function analogChannels(getter,sides)
    local out={}
    for _,side in ipairs(sides) do local value,ok=getter(side); out[#out+1]={side=side,label=side,open=ok and (tonumber(value) or 0)>0 or false,readable=ok} end
    return out
end
local function actuatorish(ptype)
    local n=norm(ptype)
    return n:find("redstone",1,true) or n:find("relay",1,true) or n:find("door",1,true) or n:find("gate",1,true) or n:find("piston",1,true) or n:find("switch",1,true)
end

local function readControllers()
    local out={}
    if type(redstone)=="table" and type(redstone.getOutput)=="function" and type(redstone.setOutput)=="function" then
        out[#out+1]={target="computer",name="THIS COMPUTER",type="computer_redstone",kind="digital_side",channels=boolChannels(function(side)local ok,v=pcall(redstone.getOutput,side); return v,ok end,computerSides)}
    end

    local names=peripheral.getNames(); table.sort(names)
    for _,name in ipairs(names) do
        local method=methods(name); local obj=peripheral.wrap(name); local ptype=peripheralType(name)
        if obj and method.setOutput then
            out[#out+1]={target=name,name=name,type=ptype,kind="digital_side",channels=boolChannels(function(side)
                if method.getOutput then return safeCall(obj,"getOutput",false,side) end
                return commandedStates[localKey(name,side)]==true,false
            end,worldSides)}
        elseif obj and method.setAnalogOutput then
            out[#out+1]={target=name,name=name,type=ptype,kind="analog_side",channels=analogChannels(function(side)
                if method.getAnalogOutput then return safeCall(obj,"getAnalogOutput",0,side) end
                return commandedStates[localKey(name,side)] and 15 or 0,false
            end,worldSides)}
        elseif obj and ((method.open and method.close) or method.setOpen) then
            local isOpen=commandedStates[name]==true; if method.isOpen then isOpen=safeCall(obj,"isOpen",false)==true end
            out[#out+1]={target=name,name=name,type=ptype,kind="native_door",channels={{side=nil,label="DOOR",open=isOpen,readable=method.isOpen==true}}}
        elseif obj and actuatorish(ptype) and (method.setEnabled or method.setActive) then
            local state=commandedStates[name]==true; local readable=false
            if method.isEnabled then state=safeCall(obj,"isEnabled",false)==true; readable=true
            elseif method.isActive then state=safeCall(obj,"isActive",false)==true; readable=true end
            out[#out+1]={target=name,name=name,type=ptype,kind=method.setEnabled and "enabled_actuator" or "active_actuator",channels={{side=nil,label="ACTUATOR",open=state,readable=readable}}}
        end
    end
    return out
end

local function setActuator(target,side,kind,value)
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
        if not method.setAnalogOutput or not allowed(side,worldSides) then error("invalid analog redstone actuator") end
        local _,ok=safeCall(obj,"setAnalogOutput",nil,side,value and 15 or 0); if not ok then error("analog actuator rejected output") end
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

local function readActuator(target,side,kind)
    if target=="computer" then return redstone.getOutput(side)==true end
    local obj=peripheral.wrap(target); if not obj then return false end; local method=methods(target)
    if kind=="digital_side" and method.getOutput then local v,ok=safeCall(obj,"getOutput",false,side); if ok then return v==true end
    elseif kind=="analog_side" and method.getAnalogOutput then local v,ok=safeCall(obj,"getAnalogOutput",0,side); if ok then return (tonumber(v) or 0)>0 end
    elseif kind=="native_door" and method.isOpen then local v,ok=safeCall(obj,"isOpen",false); if ok then return v==true end
    elseif kind=="enabled_actuator" and method.isEnabled then local v,ok=safeCall(obj,"isEnabled",false); if ok then return v==true end
    elseif kind=="active_actuator" and method.isActive then local v,ok=safeCall(obj,"isActive",false); if ok then return v==true end end
    return commandedStates[side and localKey(target,side) or target]==true
end

local function candidateList(controllers,localEntries)
    local byLocal={}; for _,entry in ipairs(localEntries or {}) do byLocal[entry.key or localKey(entry.target,entry.side)]=entry end
    local candidates,localDoors={},{}
    for _,controller in ipairs(controllers or {}) do
        for _,channel in ipairs(controller.channels or {}) do
            local key=localKey(controller.target,channel.side); local saved=byLocal[key]
            local candidate={target=controller.target,side=channel.side,label=channel.label or channel.side,controller=controller.name,type=controller.type,kind=controller.kind,open=channel.open==true,readable=channel.readable==true,localKey=key,localConfigured=saved~=nil,localName=saved and saved.name or nil}
            candidates[#candidates+1]=candidate
            if saved then localDoors[#localDoors+1]={id="local:"..key,key=key,name=saved.name or ((channel.label or channel.side or "LOCAL").." DOOR"),target=controller.target,side=channel.side,controller=controller.name,type=controller.type,kind=saved.kind or controller.kind,open=channel.open==true,readable=channel.readable==true,online=true,localConfigured=true} end
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
    return nil
end

function M.handleCommand(action,args)
    args=type(args)=="table" and args or {}
    if action=="register_local" then
        local target=tostring(args.target or ""); local side=args.side and tostring(args.side) or nil
        if target=="" then error("local door target is required") end
        local controller,channel=findCandidate(target,side); if not controller or not channel then error("local door actuator is not attached") end
        local entries=loadLocalDoors(); local key=localKey(target,side)
        for _,entry in ipairs(entries) do if (entry.key or localKey(entry.target,entry.side))==key then return entry end end
        local label=tostring(args.name or "")
        if label=="" then local sideName=tostring(channel.label or channel.side or "DOOR"):upper(); label=sideName=="DOOR" and "LOCAL DOOR" or (sideName.." DOOR") end
        local entry={key=key,name=label,target=target,side=side,kind=controller.kind,type=controller.type}
        entries[#entries+1]=entry; saveLocalDoors(entries); return entry
    elseif action=="remove_local" then
        local wanted=tostring(args.key or localKey(args.target,args.side)); local entries=loadLocalDoors()
        for i,entry in ipairs(entries) do if (entry.key or localKey(entry.target,entry.side))==wanted then table.remove(entries,i); saveLocalDoors(entries); return entry end end
        error("local door is not configured")
    end

    local target=tostring(args.target or ""); local side=args.side and tostring(args.side) or nil
    if target=="" then error("door target is required") end
    if action~="open" and action~="close" and action~="toggle" and action~="pulse" then error("unsupported door action") end
    local controller,channel=findCandidate(target,side); if not controller or not channel then error("door actuator is not attached") end
    local current=readActuator(target,side,controller.kind)
    local desired=action=="open" or (action=="toggle" and not current) or action=="pulse"
    setActuator(target,side,controller.kind,desired)
    if action=="pulse" then local seconds=math.max(0.05,math.min(5,tonumber(args.seconds) or 1)); sleep(seconds); setActuator(target,side,controller.kind,false); desired=false end
    return {target=target,side=side,kind=controller.kind,open=desired,action=action}
end

return M
