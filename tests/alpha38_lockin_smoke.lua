local realPrint=print
colors={white=1,orange=2,magenta=4,lightBlue=8,yellow=16,lime=32,pink=64,gray=128,lightGray=256,cyan=512,purple=1024,blue=2048,brown=4096,green=8192,red=16384,black=32768}

local function surface(width,height)
    local rows,x,y={},1,1; local s={lastScale=nil}
    s.setTextScale=function(v)s.lastScale=v end; s.setBackgroundColor=function()end; s.setTextColor=function()end
    s.clear=function()rows={};x,y=1,1 end; s.setCursorPos=function(nx,ny)x,y=nx,ny end; s.getSize=function()return width,height end
    s.write=function(value) value=tostring(value or ""); if y<1 or y>height or x>width then return end; value=value:sub(1,math.max(0,width-x+1)); local row=rows[y] or string.rep(" ",width); rows[y]=row:sub(1,x-1)..value..row:sub(x+#value); x=x+#value end
    s.output=function()local out={};for i=1,height do out[i]=rows[i] or string.rep(" ",width) end;return table.concat(out,"\n") end
    return s
end
local function methodsOf(obj)local out={};for k,v in pairs(obj or {})do if type(v)=="function" then out[#out+1]=k end end;table.sort(out);return out end

local devices={}; peripheral={}
peripheral.getNames=function()local out={};for n in pairs(devices)do out[#out+1]=n end;table.sort(out);return out end
peripheral.hasType=function(name,wanted)return devices[name] and devices[name].type==wanted or false end
peripheral.wrap=function(name)return devices[name] and devices[name].object end
peripheral.getType=function(name)return devices[name] and devices[name].type end
peripheral.getMethods=function(name)return methodsOf(devices[name] and devices[name].object) end
peripheral.isPresent=function(name)return devices[name]~=nil end

term={clear=function()end,setCursorPos=function()end,setTextColor=function()end}
local epoch=2000
os={getComputerID=function()return 42 end,getComputerLabel=function()return "Front Gate" end,epoch=function()epoch=epoch+1;return epoch end,time=function()return 20.5 end,day=function()return 8 end}

-- Peripheral diagnostics: monitor+modem only must be identified as infrastructure,
-- not silently reported as mysterious missing sensors.
devices.monitor={type="monitor",object=surface(42,24)}
devices.modem={type="modem",object={isWireless=function()return false end}}
local attachments=assert(loadfile("modules/attachments.lua"))().read()
assert(attachments.sensorCount==0,"infrastructure became a fake sensor")
assert(attachments.dataCount==0,"monitor/modem became fake data peripherals")
assert(attachments.diagnostics and attachments.diagnostics.onlyInfrastructure==true,"infrastructure-only link was not diagnosed")
assert(tostring(attachments.diagnostics.hint):find("wired modem",1,true),"sensor wiring hint is missing")

-- New/unknown detector names should still surface if their API is observational.
devices.weatherProbe={type="some_mod:climateProbe",object={getTemperature=function()return 19.5 end,getHumidity=function()return 61 end,getName=function()return "Workshop Climate" end}}
attachments=assert(loadfile("modules/attachments.lua"))().read()
assert(attachments.sensorCount>=1,"unknown observational detector was hidden")
local found=false; for _,s in ipairs(attachments.sensors)do if s.name=="weatherProbe" then found=true end end
assert(found,"observational detector missing from sensor list")

-- Room panel: dedicated controller wins, setup completes, operational panel appears,
-- sensor remains visible, and door mode control exists for piston/redstone setups.
for k in pairs(devices)do devices[k]=nil end
local mon=surface(42,24); devices.monitor={type="monitor",object=mon}
local adaptive=assert(loadfile("clients/adaptive_v7.lua"))(); local wall=adaptive.create({mode="wall"}); wall.init({name="KIMI-42"})
local sensor={name="env",type="environment_detector",metrics={temperature=19.5,biome="minecraft:plains"},summary="plains"}
local candidates={}
for _,side in ipairs({"north","south","east","west","up","down"})do candidates[#candidates+1]={target="redstone_integrator_0",side=side,label=side,controller="redstone_integrator_0",type="redstone_integrator",kind="digital_side",priority=1,localConfigured=false} end
for _,side in ipairs({"top","bottom","left","right","front","back"})do candidates[#candidates+1]={target="computer",side=side,label=side,controller="THIS COMPUTER",type="computer_redstone",kind="digital_side",priority=9,localConfigured=false} end
local meta={connected=true,localServer=false,localState={doors={candidates=candidates,localDoors={}},attachments={sensors={sensor},devices={sensor},dataCount=1,diagnostics={onlyInfrastructure=false,hint="sensor link healthy"}},power={onlineSources=0}}}
local env={version="5.0.0-alpha.38",state={doors={doors={}},attachments={sensors={sensor},devices={sensor}},fleet={[1]={role="server",name="Main Base",version="5.0.0-alpha.38",online=true},[42]={role="client",name="Front Gate",version="5.0.0-alpha.38",online=true}},sources={["42"]={name="Front Gate"}},power={onlineSources=0}}}
wall.render(env,meta)
local out=mon.output()
assert(out:find("SET UP DOOR",1,true),"room setup title missing")
assert(out:find("REDSTONE INTEGRATOR",1,true),"dedicated controller did not win")
assert(not out:find("THIS COMPUTER",1,true),"built-in redstone stole setup priority")
assert(out:find("WEST",1,true),"piston/redstone output grid missing")
assert(out:find("1 LINKED",1,true),"sensor status disappeared during setup")

local called
wall.handleEvent({"monitor_touch","monitor",5,19},env,function(module,action,args)
    called={module=module,action=action,args=args}
    if action=="register_local" then
        meta.localState.doors.localDoors={{id="local:redstone_integrator_0|west",key="redstone_integrator_0|west",name="FRONT GATE",target="redstone_integrator_0",side="west",kind="digital_side",mode="hold",supportsModes=true,online=true,open=false}}
        return true,meta.localState.doors.localDoors[1]
    end
    return true
end)
assert(called and called.action=="register_local" and called.args.side=="west","door side tap did not register west output")
out=mon.output()
assert(out:find("OPEN DOOR",1,true),"successful setup did not return to operational door screen")
assert(not out:find("WHICH OUTPUT OPENS THE DOOR",1,true),"setup wizard remained stuck")
assert(out:find("MODE  HOLD",1,true),"piston/redstone mode selector missing")
assert(out:find("1 LINKED",1,true),"sensor status disappeared after setup")

-- Room panel with only monitor/modem must show a wiring diagnosis, not debug junk.
meta.localState.attachments={sensors={},devices={{type="monitor"},{type="modem"}},dataCount=0,diagnostics={onlyInfrastructure=true,hint="only monitor/modem infrastructure is visible; connect detector adjacent to this computer or through an attached wired modem"}}
wall.render(env,meta); out=mon.output()
assert(out:find("SENSOR",1,true) and out:find("NOT CONNECTED",1,true),"room panel did not show sensor link failure")
assert(out:find("WIRED MODEM",1,true),"room panel did not explain how to connect the detector")
assert(not out:find("PERIPHERALS  2",1,true),"debug peripheral counter leaked into appliance UI")

-- Admin overview must derive fleet state from reality, not stale 'discovering fleet'.
for k in pairs(devices)do devices[k]=nil end
local adminMon=surface(68,30); devices.admin={type="monitor",object=adminMon}
os.getComputerLabel=function()return "Main Base" end
local admin=adaptive.create({mode="admin"}); admin.init({name="Main Base"})
local power={onlineSources=1,stored=750,capacity=1000,input=50,output=20,filledPercentage=.75,matrices={{stored=750,capacity=1000,input=50,output=20,filledPercentage=.75}}}
local adminEnv={version="5.0.0-alpha.38",state={doors={doors={{name="FRONT GATE",online=true,open=false}}},attachments={sensors={},devices={},diagnostics={}},power=power,fleet={[1]={role="server",name="Main Base",version="5.0.0-alpha.38",online=true},[2]={role="node",name="Remote Node",version="5.0.0-alpha.38",online=true},[42]={role="client",name="Front Gate",version="5.0.0-alpha.38",online=true}},update={syncResult="DISCOVERING FLEET"}}}
admin.render(adminEnv,{connected=true,localServer=true,localState={power=power,attachments={sensors={}}}})
out=adminMon.output()
assert(out:find("FLEET LOCKED 3/3",1,true),"overview still trusts stale discovering-fleet text")
assert(not out:find("DISCOVERING FLEET",1,true),"stale fleet-sync status leaked into overview")
assert(out:find("SENSOR BUS",1,true),"overview does not surface missing detector telemetry")

-- Door implementation must keep universal actuator modes. Do not rely on the
-- old minified source formatting: alpha45 deliberately rewrites the module.
local f=assert(io.open("modules/doors.lua","r")); local doorSource=f:read("*a"); f:close()
assert(doorSource:find('"pulse"',1,true) and doorSource:find('"toggle"',1,true),"pulse/toggle door mode missing")
assert(doorSource:find('"invert"',1,true),"inverted-hold door mode missing")
assert(doorSource:find('setAnalogOutput',1,true),"analog redstone actuator support missing")
assert(doorSource:find('setEnabled',1,true) and doorSource:find('setActive',1,true),"relay/piston actuator support missing")

realPrint("alpha38 lock-in smoke test OK")
