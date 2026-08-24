local M={id="doors"}
local ROOT=".kimi";local LOCAL_PATH=ROOT.."/local_doors"
local computerSides={"top","bottom","left","right","front","back"}
local worldSides={"north","south","east","west","up","down"}
local commandedStates={}

local function safeCall(obj,method,fallback,...)
 if not obj or type(obj[method])~="function"then return fallback,false end
 local ok,value=pcall(obj[method],...);if not ok then return fallback,false end;return value,true
end
local function methodSet(name)local ok,v=pcall(peripheral.getMethods,name);local out={};if ok and type(v)=="table"then for _,m in ipairs(v)do out[m]=true end end;return out end
local function ptype(name)local ok,v=pcall(peripheral.getType,name);return ok and tostring(v or"unknown")or"unknown"end
local function norm(v)return tostring(v or""):lower():gsub("[^a-z0-9]","")end
local function key(target,side)return tostring(target or"").."|"..tostring(side or"")end
local function allowed(v,list)for _,x in ipairs(list)do if x==v then return true end end;return false end
local function supportsModes(kind)return kind~="native_door"end
local function normalizeMode(e)local m=tostring(e and e.mode or"hold");if m~="hold"and m~="invert"and m~="pulse"then m="hold"end;return m end
local function readFile(path)if not fs.exists(path)or fs.isDir(path)then return nil end;local f=fs.open(path,"r");if not f then return nil end;local b=f.readAll();f.close();return b end
local function loadDoors()local raw=readFile(LOCAL_PATH);local v=raw and textutils.unserialize(raw)or nil;if type(v)~="table"then return{}end;local out={};for _,e in ipairs(v)do if type(e)=="table"and e.target then e.key=e.key or key(e.target,e.side);e.mode=normalizeMode(e);e.pulseSeconds=math.max(.05,math.min(5,tonumber(e.pulseSeconds)or.5));out[#out+1]=e end end;return out end
local function saveDoors(v)if not fs.exists(ROOT)then fs.makeDir(ROOT)end;local f=assert(fs.open(LOCAL_PATH,"w"));f.write(textutils.serialize(v or{}));f.close()end
local function actuatorish(t)local n=norm(t);return n:find("redstone",1,true)or n:find("relay",1,true)or n:find("door",1,true)or n:find("gate",1,true)or n:find("piston",1,true)or n:find("switch",1,true)end

local function computerInput(side)local ok,v=pcall(redstone.getInput,side);return ok and v==true,ok end
local function peripheralOutput(obj,m,side)
 if m.getOutput then local v,ok=safeCall(obj,"getOutput",false,side);if ok then return v==true,true end end
 if m.getAnalogOutput then local v,ok=safeCall(obj,"getAnalogOutput",0,side);if ok then return(tonumber(v)or 0)>0,true end end
 if m.getAnalogueOutput then local v,ok=safeCall(obj,"getAnalogueOutput",0,side);if ok then return(tonumber(v)or 0)>0,true end end
 return false,false
end
local function peripheralInput(obj,m,side)
 if m.getInput then local v,ok=safeCall(obj,"getInput",false,side);if ok then return v==true,true end end
 if m.getAnalogInput then local v,ok=safeCall(obj,"getAnalogInput",0,side);if ok then return(tonumber(v)or 0)>0,true end end
 if m.getAnalogueInput then local v,ok=safeCall(obj,"getAnalogueInput",0,side);if ok then return(tonumber(v)or 0)>0,true end end
 return false,false
end
local function sideChannels(target,obj,m,sides)
 local out={};for _,side in ipairs(sides)do local output,readable=peripheralOutput(obj,m,side);if not readable then output=commandedStates[key(target,side)]==true end;local input,inputReadable=peripheralInput(obj,m,side);out[#out+1]={side=side,label=side,signal=output,readable=readable,input=input,inputReadable=inputReadable}end;return out
end

local function controllers()
 local out={};local names=peripheral.getNames();table.sort(names)
 for _,name in ipairs(names)do local m=methodSet(name);local obj=peripheral.wrap(name);local typ=ptype(name)
  if obj and m.setOutput then out[#out+1]={target=name,name=name,type=typ,kind="digital_side",priority=1,channels=sideChannels(name,obj,m,worldSides)}
  elseif obj and(m.setAnalogOutput or m.setAnalogueOutput)then out[#out+1]={target=name,name=name,type=typ,kind="analog_side",priority=1,channels=sideChannels(name,obj,m,worldSides)}
  elseif obj and((m.open and m.close)or m.setOpen)then local s=commandedStates[name]==true;local r=false;if m.isOpen then s,r=safeCall(obj,"isOpen",false)end;out[#out+1]={target=name,name=name,type=typ,kind="native_door",priority=0,channels={{side=nil,label="DOOR",signal=s==true,readable=r==true,input=s==true,inputReadable=r==true}}}
  elseif obj and actuatorish(typ)and(m.setEnabled or m.setActive)then local s=commandedStates[name]==true;local r=false;if m.isEnabled then s,r=safeCall(obj,"isEnabled",false)elseif m.isActive then s,r=safeCall(obj,"isActive",false)end;out[#out+1]={target=name,name=name,type=typ,kind=m.setEnabled and"enabled_actuator"or"active_actuator",priority=1,channels={{side=nil,label="ACTUATOR",signal=s==true,readable=r==true,input=s==true,inputReadable=r==true}}}end
 end
 if type(redstone)=="table"and type(redstone.setOutput)=="function"then local ch={};for _,side in ipairs(computerSides)do local o=redstone.getOutput(side)==true;local i,ir=computerInput(side);ch[#ch+1]={side=side,label=side,signal=o,readable=true,input=i,inputReadable=ir}end;out[#out+1]={target="computer",name="THIS COMPUTER",type="computer_redstone",kind="digital_side",priority=9,channels=ch}end
 table.sort(out,function(a,b)if(a.priority or 5)~=(b.priority or 5)then return(a.priority or 5)<(b.priority or 5)end;return tostring(a.target)<tostring(b.target)end);return out
end
local function findController(target)for _,c in ipairs(controllers())do if tostring(c.target)==tostring(target)then return c end end end
local function findCandidate(target,side)local c=findController(target);if not c then return nil end;for _,ch in ipairs(c.channels or{})do if tostring(ch.side or"")==tostring(side or"")then return c,ch end end end
local function findEntry(entries,target,side)local k=key(target,side);for i,e in ipairs(entries)do if(e.key or key(e.target,e.side))==k then return e,i end end end

local function setOutput(target,side,c,value)
 if target=="computer"then if not allowed(side,computerSides)then error("invalid computer redstone side")end;redstone.setOutput(side,value);commandedStates[key(target,side)]=value;return end
 if not peripheral.isPresent(target)then error("door actuator is not attached")end;local obj=peripheral.wrap(target);local m=methodSet(target)
 if c.kind=="digital_side"then if not m.setOutput or not allowed(side,worldSides)then error("invalid redstone actuator")end;local _,ok=safeCall(obj,"setOutput",nil,side,value);if not ok then error("redstone actuator rejected output")end
 elseif c.kind=="analog_side"then local setter=m.setAnalogOutput and"setAnalogOutput"or(m.setAnalogueOutput and"setAnalogueOutput"or nil);if not setter or not allowed(side,worldSides)then error("invalid analog actuator")end;local _,ok=safeCall(obj,setter,nil,side,value and 15 or 0);if not ok then error("analog actuator rejected output")end
 elseif c.kind=="native_door"then local ok;if m.setOpen then _,ok=safeCall(obj,"setOpen",nil,value)elseif value and m.open then _,ok=safeCall(obj,"open",nil)elseif(not value)and m.close then _,ok=safeCall(obj,"close",nil)end;if not ok then error("door peripheral rejected command")end
 elseif c.kind=="enabled_actuator"and m.setEnabled then local _,ok=safeCall(obj,"setEnabled",nil,value);if not ok then error("actuator rejected setEnabled")end
 elseif c.kind=="active_actuator"and m.setActive then local _,ok=safeCall(obj,"setActive",nil,value);if not ok then error("actuator rejected setActive")end
 else error("unsupported door actuator")end
 commandedStates[side and key(target,side)or target]=value
end
local function liveSignals(target,side,c)
 if target=="computer"then local o=redstone.getOutput(side)==true;local i,ir=computerInput(side);return o,true,i,ir end
 local obj=peripheral.wrap(target);if not obj then return false,false,false,false end;local m=methodSet(target)
 if c.kind=="digital_side"or c.kind=="analog_side"then local o,orx=peripheralOutput(obj,m,side);if not orx then o=commandedStates[key(target,side)]==true end;local i,ir=peripheralInput(obj,m,side);return o,orx,i,ir end
 if c.kind=="native_door"and m.isOpen then local v,ok=safeCall(obj,"isOpen",false);return v==true,ok,v==true,ok end
 if c.kind=="enabled_actuator"and m.isEnabled then local v,ok=safeCall(obj,"isEnabled",false);return v==true,ok,v==true,ok end
 if c.kind=="active_actuator"and m.isActive then local v,ok=safeCall(obj,"isActive",false);return v==true,ok,v==true,ok end
 local v=commandedStates[side and key(target,side)or target]==true;return v,false,false,false
end
local function feedbackSignal(entry,c)
 if not entry.feedbackSide then return nil,false end
 local side=tostring(entry.feedbackSide);if c.target=="computer"then local v,ok=computerInput(side);return v,ok end
 local obj=peripheral.wrap(c.target);if not obj then return nil,false end;local m=methodSet(c.target);local v,ok=peripheralInput(obj,m,side);return v,ok
end
local function logicalState(entry,c,output)
 local fb,fbOk=feedbackSignal(entry,c);if fbOk then local v=fb;if entry.feedbackInvert then v=not v end;return v,"feedback" end
 local mode=normalizeMode(entry);if mode=="invert"and supportsModes(c.kind)then return not output,"output"end;if mode=="pulse"then return commandedStates["logical:"..key(entry.target,entry.side)]==true,"command"end;return output,"output"
end

local function buildLists(ctrls,entries)
 local saved={};for _,e in ipairs(entries)do saved[e.key or key(e.target,e.side)]=e end;local candidates,doors={},{}
 for _,c in ipairs(ctrls)do for _,ch in ipairs(c.channels or{})do local k=key(c.target,ch.side);local e=saved[k];local cand={target=c.target,side=ch.side,label=ch.label,controller=c.name,type=c.type,kind=c.kind,priority=c.priority,signal=ch.signal==true,inputSignal=ch.input==true,inputReadable=ch.inputReadable==true,readable=ch.readable==true,localKey=k,localConfigured=e~=nil,localName=e and e.name or nil};candidates[#candidates+1]=cand;if e then local open,source=logicalState(e,c,ch.signal==true);doors[#doors+1]={id="local:"..k,key=k,name=e.name or((ch.label or ch.side or"LOCAL").." DOOR"),target=c.target,side=ch.side,controller=c.name,type=c.type,kind=c.kind,mode=normalizeMode(e),pulseSeconds=tonumber(e.pulseSeconds)or.5,open=open,signal=ch.signal==true,inputSignal=ch.input==true,inputReadable=ch.inputReadable==true,stateSource=source,feedbackSide=e.feedbackSide,feedbackInvert=e.feedbackInvert==true,online=true,localConfigured=true,supportsModes=supportsModes(c.kind)}end end end;return candidates,doors
end

function M.read()local cs=controllers();local entries=loadDoors();local candidates,localDoors=buildLists(cs,entries);local n=0;for _,c in ipairs(cs)do n=n+#(c.channels or{})end;return{controllers=cs,controllerCount=#cs,candidates=candidates,candidateCount=#candidates,localDoors=localDoors,localDoorCount=#localDoors,channelCount=n,_status="online",_updated=os.epoch("utc")}end

function M.handleCommand(action,args)
 args=type(args)=="table"and args or{};local target=tostring(args.target or"");local side=args.side and tostring(args.side)or nil
 if action=="register_local"then if target==""then error("local door target is required")end;local c,ch=findCandidate(target,side);if not c or not ch then error("local door actuator is not attached")end;local entries=loadDoors();local existing=findEntry(entries,target,side);if existing then return existing end;local label=tostring(args.name or"");if label==""then local s=tostring(ch.label or side or"DOOR"):upper();label=s=="DOOR"and"LOCAL DOOR"or(s.." DOOR")end;local e={key=key(target,side),name=label,target=target,side=side,kind=c.kind,type=c.type,mode="hold",pulseSeconds=.5};entries[#entries+1]=e;saveDoors(entries);return e end
 if action=="configure_local"then local entries=loadDoors();local e=findEntry(entries,target,side);if not e then error("local door is not configured")end;local c=findController(target);if not c then error("door actuator is not attached")end;local mode=tostring(args.mode or e.mode or"hold");if mode~="hold"and mode~="invert"and mode~="pulse"then error("invalid door mode")end;if not supportsModes(c.kind)and mode~="hold"then mode="hold"end;e.mode=mode;e.pulseSeconds=math.max(.05,math.min(5,tonumber(args.pulseSeconds)or tonumber(e.pulseSeconds)or.5));if args.feedbackSide~=nil then local f=tostring(args.feedbackSide);if f==""or f=="none"then e.feedbackSide=nil else e.feedbackSide=f end end;if args.feedbackInvert~=nil then e.feedbackInvert=args.feedbackInvert==true end;saveDoors(entries);return e end
 if action=="remove_local"then local entries=loadDoors();local _,i=findEntry(entries,target,side);if not i then error("local door is not configured")end;local old=table.remove(entries,i);saveDoors(entries);return old end
 if target==""then error("door target is required")end;if action~="open"and action~="close"and action~="toggle"and action~="pulse"then error("unsupported door action")end;local c=findController(target);if not c then error("door actuator is not attached")end;local entries=loadDoors();local e=findEntry(entries,target,side)or{target=target,side=side,mode="hold",pulseSeconds=.5};local mode=normalizeMode(e)
 if action=="pulse"or mode=="pulse"then local seconds=math.max(.05,math.min(5,tonumber(args.seconds)or tonumber(e.pulseSeconds)or.5));setOutput(target,side,c,true);sleep(seconds);setOutput(target,side,c,false);local k="logical:"..key(target,side);commandedStates[k]=not(commandedStates[k]==true);return{target=target,side=side,kind=c.kind,mode="pulse",open=commandedStates[k],signal=false,action="pulse"}end
 local output=select(1,liveSignals(target,side,c));local current=select(1,logicalState(e,c,output));local desired=action=="open"or(action=="toggle"and not current);local physical=(mode=="invert"and supportsModes(c.kind))and(not desired)or desired;setOutput(target,side,c,physical);return{target=target,side=side,kind=c.kind,mode=mode,open=desired,signal=physical,action=action}
end
return M
