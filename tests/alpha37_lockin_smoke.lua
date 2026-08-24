local realPrint=print
colors={white=1,orange=2,magenta=4,lightBlue=8,yellow=16,lime=32,pink=64,gray=128,lightGray=256,cyan=512,purple=1024,blue=2048,brown=4096,green=8192,red=16384,black=32768}

local function surface(width,height)
    local rows,x,y={},1,1; local s={lastScale=nil}
    s.setTextScale=function(v)s.lastScale=v end; s.setBackgroundColor=function()end; s.setTextColor=function()end
    s.clear=function() rows={}; x,y=1,1 end; s.setCursorPos=function(nx,ny)x,y=nx,ny end; s.getSize=function()return width,height end
    s.write=function(value) value=tostring(value or ""); if y<1 or y>height or x>width then return end; value=value:sub(1,math.max(0,width-x+1)); local row=rows[y] or string.rep(" ",width); rows[y]=row:sub(1,x-1)..value..row:sub(x+#value); x=x+#value end
    s.output=function() local out={}; for i=1,height do out[i]=rows[i] or string.rep(" ",width) end; return table.concat(out,"\n") end
    return s
end
local function methodsOf(obj) local out={}; for k,v in pairs(obj or {}) do if type(v)=="function" then out[#out+1]=k end end; table.sort(out); return out end

local devices={}; peripheral={}
peripheral.getNames=function()local out={};for n in pairs(devices)do out[#out+1]=n end;table.sort(out);return out end
peripheral.hasType=function(name,wanted)return devices[name] and devices[name].type==wanted or false end
peripheral.wrap=function(name)return devices[name] and devices[name].object end
peripheral.getType=function(name)return devices[name] and devices[name].type end
peripheral.getMethods=function(name)return methodsOf(devices[name] and devices[name].object) end
peripheral.isPresent=function(name)return devices[name]~=nil end

term={clear=function()end,setCursorPos=function()end,setTextColor=function()end}
local epoch=1000
os={getComputerID=function()return 42 end,getComputerLabel=function()return "Front Gate" end,epoch=function()epoch=epoch+1;return epoch end,time=function()return 14.5 end,day=function()return 8 end}

-- SENSOR REGRESSION: namespaced/camel-case Advanced Peripherals style types
-- and current observation methods must classify, while ME storage stays out.
devices.me={type="me_bridge",object={isOnline=function()return true end,getStoredEnergy=function()return 999 end}}
devices.env={type="advancedperipherals:environmentDetector",object={getBiome=function()return "minecraft:plains" end,isThundering=function()return false end,getSolarRadiation=function()return 12 end}}
devices.player={type="playerDetector",object={getOnlinePlayers=function()return {"Stig"} end}}
local attachments=assert(loadfile("modules/attachments.lua"))().read()
assert(attachments.sensorCount==2,"environment/player detectors were not both classified as sensors")
local names={}; for _,s in ipairs(attachments.sensors) do names[s.name]=true end
assert(names.env and names.player,"expected detector peripherals missing from sensor list")
assert(not names.me,"ME bridge regressed into fake sensor")

-- ROOM UI REGRESSION: dedicated controller beats built-in computer redstone,
-- sensor stays visible, selecting an output completes setup and returns to door control.
for k in pairs(devices)do devices[k]=nil end
local mon=surface(42,24); devices.monitor={type="monitor",object=mon}
local adaptive=assert(loadfile("clients/adaptive_v6.lua"))(); local wall=adaptive.create({mode="wall"}); wall.init({name="KIMI-42"})
local sensor={name="env",type="environment_detector",metrics={biome="minecraft:plains",solarRadiation=12},summary="plains",_source="42"}
local candidates={}
for _,side in ipairs({"north","south","east","west","up","down"}) do candidates[#candidates+1]={target="redstone_integrator_0",side=side,label=side,controller="redstone_integrator_0",type="redstone_integrator",kind="digital_side",localConfigured=false} end
for _,side in ipairs({"top","bottom","left","right","front","back"}) do candidates[#candidates+1]={target="computer",side=side,label=side,controller="THIS COMPUTER",type="computer_redstone",kind="digital_side",localConfigured=false} end
local meta={connected=true,localServer=false,localState={doors={candidates=candidates,localDoors={}},attachments={sensors={sensor},devices={sensor}},power={onlineSources=0}}}
local env={version="5.0.0-alpha.37",state={doors={doors={}},attachments={sensors={sensor},devices={sensor}},fleet={[1]={role="server",name="Main",version="5.0.0-alpha.37",online=true},[42]={role="client",name="Front Gate",version="5.0.0-alpha.37",online=true}},sources={["42"]={name="Front Gate"}},power={onlineSources=0}}}
wall.render(env,meta)
local out=mon.output()
assert(out:find("REDSTONE INTEGRATOR",1,true),"dedicated redstone controller was not preferred")
assert(not out:find("THIS COMPUTER",1,true),"built-in computer redstone incorrectly stole setup priority")
assert(out:find("WEST",1,true),"piston/redstone side choices missing")
assert(out:find("SENSORS",1,true) and out:find("1 ONLINE",1,true),"local sensor disappeared during door setup")

local called
wall.handleEvent({"monitor_touch","monitor",5,16},env,function(module,action,args)
    called={module=module,action=action,args=args}
    meta.localState.doors.localDoors={{id="local:redstone_integrator_0|west",key="redstone_integrator_0|west",name="FRONT GATE",target="redstone_integrator_0",side="west",kind="digital_side",online=true,open=false}}
    return true,meta.localState.doors.localDoors[1]
end)
assert(called and called.module=="__local_doors" and called.action=="register_local","side tap did not register a local door")
out=mon.output()
assert(out:find("OPEN DOOR",1,true),"successful door setup did not return to normal room control")
assert(not out:find("WHICH OUTPUT OPENS THE DOOR",1,true),"wizard remained stuck after successful setup")

-- EMPTY SENSOR PAGE must expose what ComputerCraft actually sees, not a blank void.
meta.localState.attachments={sensors={},devices={{type="mystery_weather_probe",name="probe"}}}
local wall2=adaptive.create({mode="wall"}); wall2.init({name="Room"}); wall2.render(env,meta)
assert(mon.output():find("MYSTERY WEATHER PROBE",1,true) or mon.output():find("PERIPHERALS",1,true),"zero-sensor diagnostics hid detected peripheral types")

-- Critical command-boundary regression: registration must not require _source.
local f=assert(io.open("roles/client.lua","r")); local clientSource=f:read("*a"); f:close()
assert(clientSource:find('action ~= "register_local"',1,true),"client local-door guard would reject registration again")

-- Fleet architecture regression: server must persist known machines and actively discover hosts.
local sf=assert(io.open("roles/server.lua","r")); local serverSource=sf:read("*a"); sf:close()
assert(serverSource:find("fleetRegistry.load",1,true),"server forgets fleet across reboot")
assert(serverSource:find("network.lookupAll",1,true),"server does not actively discover KIMI hosts")
assert(serverSource:find("post%-probation"),"server does not reconcile fleet after its own update probation")

realPrint("alpha37 lock-in smoke test OK")
