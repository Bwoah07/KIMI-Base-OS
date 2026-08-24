local realPrint = print

colors = {
    white=1, orange=2, magenta=4, lightBlue=8, yellow=16, lime=32,
    pink=64, gray=128, lightGray=256, cyan=512, purple=1024,
    blue=2048, brown=4096, green=8192, red=16384, black=32768
}

local function surface(width,height)
    local rows,x,y={},1,1
    local s={lastScale=nil}
    s.setTextScale=function(value) s.lastScale=value end
    s.setBackgroundColor=function() end
    s.setTextColor=function() end
    s.clear=function() rows={}; x,y=1,1 end
    s.setCursorPos=function(nx,ny) x,y=nx,ny end
    s.getSize=function() return width,height end
    s.write=function(value)
        value=tostring(value or "")
        if y<1 or y>height or x>width then return end
        value=value:sub(1,math.max(0,width-x+1))
        local row=rows[y] or string.rep(" ",width)
        rows[y]=row:sub(1,x-1)..value..row:sub(x+#value)
        x=x+#value
    end
    s.output=function()
        local out={}
        for row=1,height do out[row]=rows[row] or string.rep(" ",width) end
        return table.concat(out,"\n")
    end
    s.row=function(n) return rows[n] or string.rep(" ",width) end
    return s
end

local function methodsOf(object)
    local out={}
    for k,v in pairs(object or {}) do if type(v)=="function" then out[#out+1]=k end end
    table.sort(out); return out
end

local devices={}
peripheral={}
peripheral.getNames=function() local out={}; for name in pairs(devices) do out[#out+1]=name end; table.sort(out); return out end
peripheral.hasType=function(name,wanted) return devices[name] and devices[name].type==wanted or false end
peripheral.wrap=function(name) return devices[name] and devices[name].object end
peripheral.getType=function(name) return devices[name] and devices[name].type end
peripheral.getMethods=function(name) return methodsOf(devices[name] and devices[name].object) end
peripheral.isPresent=function(name) return devices[name]~=nil end

term={clear=function() end,setCursorPos=function() end}
local epoch=1000000
local computerLabel="Front Gate"
os={
    getComputerID=function() return 42 end,
    getComputerLabel=function() return computerLabel end,
    epoch=function() epoch=epoch+1; return epoch end,
    time=function() return 12.5 end,
    day=function() return 8 end
}

-- Current/legacy Advanced Peripherals names must both classify as sensors.
devices.me_bridge_1={type="me_bridge",object={isOnline=function() return true end,getStoredEnergy=function() return 140648.7 end}}
devices.player_detector_1={type="playerDetector",object={getOnlinePlayers=function() return {"Stig"} end}}
devices.environment_detector_1={type="environmentDetector",object={isSunny=function() return true end,getRadiationRaw=function() return 0.000001 end}}
local attachments=assert(loadfile("modules/attachments.lua"))().read()
assert(attachments.sensorCount==2,"Advanced Peripherals sensors were not discovered")
local foundPlayer,foundEnv=false,false
for _,s in ipairs(attachments.sensors) do
    foundPlayer=foundPlayer or tostring(s.type):lower():find("player",1,true)~=nil
    foundEnv=foundEnv or tostring(s.type):lower():find("environment",1,true)~=nil
end
assert(foundPlayer and foundEnv,"player/environment sensor types were lost")
for _,s in ipairs(attachments.sensors) do assert(s.name~="me_bridge_1","ME bridge was incorrectly classified as a sensor") end

for name in pairs(devices) do devices[name]=nil end
local roomMon=surface(42,24)
devices.room={type="monitor",object=roomMon}

local adaptive=assert(loadfile("clients/adaptive_v5.lua"))()
local wall=adaptive.create({mode="wall"})
wall.init({name="KIMI-42"})

local sensor={name="player_detector_1",type="playerDetector",metrics={onlinePlayers=1},_source="42"}
local nativeCandidate={target="create_door_controller_0",side=nil,label="DOOR",controller="create_door_controller_0",type="door_controller",kind="door",open=false,readable=true,localConfigured=false}
local emptyEnvelope={version="5.0.0-alpha.36",state={doors={doors={},candidates={}},attachments={sensors={sensor}},power={onlineSources=0},fleet={[42]={name="Front Gate",role="client",online=true}},sources={["42"]={name="Front Gate",role="client",online=true}}}}
local roomMeta={connected=true,localServer=false,localState={doors={candidates={nativeCandidate},localDoors={}},attachments={sensors={sensor},devices={sensor}},power={onlineSources=0}}}

wall.render(emptyEnvelope,roomMeta)
assert(roomMon.output():find("ROOM CONTROL",1,true),"room panel missing")
assert(roomMon.output():find("DOOR CONTROLLER FOUND",1,true),"native door was not recognized as a native door")
assert(roomMon.output():find("USE THIS DOOR",1,true),"native door wizard still asks for a meaningless side")
assert(not roomMon.output():find("WHICH SIDE",1,true),"native door wizard still shows redstone-side instructions")
assert(roomMon.output():find("LOCAL SENSORS  1",1,true),"door setup hid local sensors")

local called
wall.handleEvent({"monitor_touch","room",10,12},emptyEnvelope,function(module,action,args) called={module=module,action=action,args=args} end)
assert(called,"native door setup touch did nothing")
assert(called.module=="__local_doors" and called.action=="register_local","native door setup did not use local registration")
assert(called.args and called.args.target=="create_door_controller_0" and called.args.side==nil,"native door target was corrupted")

-- Redstone controllers must get a compact side grid, not a clipped sentence/button mess.
local redstoneCandidates={}
for _,side in ipairs({"north","south","east","west","up","down"}) do redstoneCandidates[#redstoneCandidates+1]={target="redstone_integrator_0",side=side,label=side,controller="redstone_integrator_0",type="redstone_integrator",kind="redstone",localConfigured=false} end
roomMeta.localState.doors={candidates=redstoneCandidates,localDoors={}}
wall.render(emptyEnvelope,roomMeta)
assert(roomMon.output():find("REDSTONE DOOR SETUP",1,true),"redstone wizard title missing")
assert(roomMon.output():find("WHICH SIDE GOES TO THE DOOR?",1,true),"redstone setup instruction is missing/clipped")
for _,label in ipairs({"NORTH","SOUTH","EAST","WEST","UP","DOWN"}) do assert(roomMon.output():find(label,1,true),"redstone side missing: "..label) end
assert(roomMon.output():find("LOCAL SENSORS  1",1,true),"redstone setup hid local sensors")

-- Once configured, the room becomes a large immediate door button plus sensor strip.
local localDoor={id="local:create_door_controller_0|",key="create_door_controller_0|",name="FRONT GATE",target="create_door_controller_0",side=nil,online=true,open=false,localConfigured=true}
roomMeta.localState.doors={candidates={},localDoors={localDoor}}
local doorEnvelope={version="5.0.0-alpha.36",state={doors={doors={{id=localDoor.id,key=localDoor.key,name="FRONT GATE",target=localDoor.target,side=nil,_source="42",source="42",online=true,open=false}},candidates={}},attachments={sensors={sensor}},power={onlineSources=0},fleet={[42]={name="Front Gate",role="client",online=true}},sources={["42"]={name="Front Gate",role="client",online=true}}}}
wall.render(doorEnvelope,roomMeta)
assert(roomMon.output():find("FRONT GATE",1,true),"configured room door did not become a door button")
assert(roomMon.output():find("LOCAL SENSORS  1",1,true),"configured door panel dropped sensor context")
called=nil
wall.handleEvent({"monitor_touch","room",5,8},doorEnvelope,function(module,action,args) called={module=module,action=action,args=args} end)
assert(called and called.module=="__local_doors" and called.action=="toggle","local door button is not immediate/local")

-- Admin pages always retain padded navigation and a working HOME path.
for name in pairs(devices) do devices[name]=nil end
local adminMon=surface(68,30)
devices.admin={type="monitor",object=adminMon}
computerLabel=nil
local admin=adaptive.create({mode="admin"})
admin.init({name="KIMI-7"})
local goodMatrix={stored=750,capacity=1000,input=50,output=20,filledPercentage=.75}
local power={onlineSources=1,matrixCount=1,fluxCount=0,stored=0,capacity=0,input=0,output=0,matrices={goodMatrix},fluxNetworks={},energyDetectors={}}
local adminEnvelope={version="5.0.0-alpha.36",state={environment={_status="online",weather="SUNNY",biome="minecraft:plains"},doors={doors={},candidates={}},attachments={sensors={sensor}},power=power,fleet={[1]={name="KIMI-7",role="server",online=true},[2]={name="KIMI-4",role="client",version="5.0.0-alpha.36",online=true,updateStatus="current"}},update={syncResult="2 current"}}}
admin.render(adminEnvelope,{connected=true,localServer=true,localState={power=power,attachments={sensors={sensor},devices={sensor}}}})
assert(adminMon.output():find("COMMAND CENTER",1,true),"admin overview missing")
assert(adminMon.output():find("MAIN BASE",1,true),"legacy KIMI id leaked into main identity")
admin.handleEvent({"monitor_touch","admin",30,30},adminEnvelope,function() end)
assert(adminMon.output():find("POWER",1,true),"power page did not open")
assert(adminMon.output():find("HOME",1,true),"power page has no HOME path")
assert(adminMon.row(29):sub(1,1)==" " and adminMon.row(29):sub(-1)==" ","nav is flush against monitor edges")
admin.handleEvent({"monitor_touch","admin",5,30},adminEnvelope,function() end)
assert(adminMon.output():find("COMMAND CENTER",1,true),"HOME did not return from power")

realPrint("adaptive display v5 smoke test OK")
