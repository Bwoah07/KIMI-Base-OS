package.path="./?.lua;./?/init.lua;"..package.path

local telemetry=require("core.telemetry_health")
local now=200000
os.epoch=function()return now end
local source={lastTelemetry=now-5000,state={power={matrices={{stored=50,capacity=100}}}}}
assert(select(1,telemetry.status(source,"ONLINE",now))=="LIVE","fresh sample from reachable computer must be LIVE")
source.lastTelemetry=now-25000
assert(select(1,telemetry.status(source,"ONLINE",now))=="CACHED","slow telemetry must be CACHED, not offline")
assert(telemetry.usable("CACHED")and telemetry.rank("LIVE")>telemetry.rank("CACHED"),"cached sample selection contract missing")
source.lastTelemetry=now-telemetry.CACHED_MS-1
assert(select(1,telemetry.status(source,"OFFLINE",now))=="EXPIRED","ancient samples must expire")

local doorRegistry=require("core.door_registry")
local doorValues={{sourceId="42",telemetryStatus="CACHED",telemetryAgeMs=25000,connected=true,value={localDoors={{target="computer",side="left",open=true,name="VAULT"}},candidates={{target="computer",side="left",open=true,localConfigured=true}}}}}
local doorCandidates=doorRegistry.candidates(doorValues);local doorKey=assert(doorCandidates[1]).key
local doorSnapshot=doorRegistry.snapshot({{id=1,key=doorKey,source="42",target="computer",side="left"}},doorCandidates)
assert(doorSnapshot.doors[1].open==true and doorSnapshot.doors[1].online==false,"cached door state must stay visible without being controllable")

local clock=100000
os.epoch=function()return clock end
peripheral={}
function peripheral.getNames()return{"reader"}end
function peripheral.getMethods()return{"getBlockName","getBlockData","getBlockState","hasBlockEntity"}end
function peripheral.getType()return"block_reader"end
function peripheral.call(_,method)
 if method=="getBlockName"then return"rftoolsbuilder:builder"end
 if method=="getBlockState"then return{powered=true}end
 if method=="hasBlockEntity"then return true end
 if method=="getBlockData"then return{Info={energy=250000,maxEnergy=1000000,mode=4,running=true,scan={x=4,y=20,z=6},minBox={x=0,y=0,z=0},maxBox={x=9,y=39,z=9}}}end
end
local builder=assert(loadfile("modules/builder.lua"))()
local first=builder.read();local b=assert(first.builders[1],"RFTools Builder was not discovered through Block Reader")
assert(b.mode=="COLLECT"and b.position=="4, 20, 6","RFTools mode/scan position was not decoded")
assert(b.sizeX==10 and b.sizeY==40 and b.sizeZ==10 and b.volume==4000,"Builder scan box was not derived")
assert(b.energyPercent==25 and b.rawFieldCount>=10 and#b.rawFields>0,"Builder energy/raw diagnostics missing")
clock=140000
local second=builder.read(first).builders[1]
assert(second.stalled==true and second.status=="STALLED"and second.issue=="NO PROGRESS","running Builder stall detection failed")

-- A machine with a Builder but no door must route to the Builder dashboard,
-- while an empty new wall computer retains the initial door wizard.
local calls={setup=0,normal=0,builder=0}
package.loaded["clients.room_v15"]={init=function()end,render=function()calls.setup=calls.setup+1 end}
package.loaded["clients.room_v16"]={init=function()end,render=function()calls.normal=calls.normal+1 end}
package.loaded["clients.builder_dashboard"]={init=function()end,render=function()calls.builder=calls.builder+1 end,handleEvent=function()return false end}
fs={exists=function()return false end}
local room=assert(loadfile("clients/room_v17.lua"))();room.init({})
room.render({}, {localState={doors={localDoors={}},builder={builders={{peripheral="reader"}}}}})
assert(calls.builder==1 and calls.setup==0,"Builder wall node was still hijacked by door setup")
room.render({}, {localState={doors={localDoors={}},builder={builders={}}}})
assert(calls.setup==1,"fresh empty wall computer lost door setup")

-- Three-monitor Command Center defaults the shared operations monitor to the
-- Builder and switches to Fleet immediately when the on-screen button is hit.
colors={white=1,orange=2,lightBlue=8,lime=32,gray=128,lightGray=256,cyan=512,blue=2048,yellow=16,red=16384,black=32768}
keys={left=203,right=205,one=2,two=3,three=4,four=5,five=6,six=7,seven=8,eight=9,nine=10}
local function surface(w,h)
 local rows,x,y={},1,1;local s={}
 s.setTextScale=function()end;s.setTextColor=function()end;s.setBackgroundColor=function()end;s.clear=function()rows={};x,y=1,1 end;s.setCursorPos=function(a,c)x,y=a,c end;s.getSize=function()return w,h end
 s.write=function(v)v=tostring(v or"");if y<1 or y>h or x>w then return end;v=v:sub(1,math.max(0,w-x+1));local row=rows[y]or string.rep(" ",w);rows[y]=row:sub(1,x-1)..v..row:sub(x+#v);x=x+#v end
 s.output=function()local out={};for i=1,h do out[i]=rows[i]or string.rep(" ",w)end;return table.concat(out,"\n")end;return s
end
local main,power,ops=surface(60,25),surface(50,20),surface(40,20)
local devices={main={type="monitor",object=main},power={type="monitor",object=power},ops={type="monitor",object=ops}}
peripheral={getNames=function()return{"main","power","ops"}end,getType=function(n)return devices[n]and devices[n].type end,hasType=function(n,t)return devices[n]and devices[n].type==t end,wrap=function(n)return devices[n]and devices[n].object end}
term={setBackgroundColor=function()end,setTextColor=function()end,clear=function()end,setCursorPos=function()end,write=function()end}
os.getComputerLabel=function()return"MAIN BASE"end;os.getComputerID=function()return 1 end;os.time=function()return 8.5 end;os.startTimer=function()return 1 end;os.cancelTimer=function()end;os.epoch=function()return 200000 end
package.loaded["clients.builder_dashboard"]=nil
for _,name in ipairs({"clients.admin_v12","clients.admin_v13","clients.admin_v14","clients.admin_v15","clients.admin_v16","clients.admin_v17","clients.admin_v18","clients.admin_v19","clients.admin_v20","clients.admin_v21","clients.admin_v22","clients.admin_v23","clients.admin_v24","clients.admin_v25","clients.admin_v26","clients.admin_v27","clients.admin_v28","clients.admin_v29","clients.admin_v30","clients.admin"})do package.loaded[name]=nil end
local admin=assert(loadfile("clients/admin.lua"))();admin.init({name="MAIN BASE"})
local adminEnv={serverId=1,version="5.0.0-alpha.82",state={fleet={[1]={lastSeen=200000,name="MAIN BASE",role="server"}},power={matrices={},fluxNetworks={}},builder={builders={{peripheral="reader",running=true,progress=42,processed=42,total=100,remaining=58,_telemetryStatus="LIVE"}}}}}
admin.render(adminEnv,{localServer=true})
assert(ops.output():find("BUILDER / QUARRY",1,true),"three-monitor base did not prioritize Builder on shared operations monitor")
admin.handleEvent({"monitor_touch","ops",39,2},adminEnv,function()return{ok=true}end)
assert(ops.output():find("FLEET / IDENTIFY",1,true),"Builder/Fleet touch switch was not responsive")

local function read(path)local f=assert(io.open(path,"r"));local text=f:read("*a");f:close();return text end
local server=read("roles/server.lua")
assert(server:find('require("core.telemetry_health")',1,true)and server:find("telemetryHealth.usable",1,true),"server does not retain labelled cached telemetry")
assert(server:find("telemetryStatus=\"LIVE\"",1,true)and server:find("_telemetryStatus",1,true),"telemetry freshness is not propagated to dashboards")
assert(server:find("nextUpdateOffer",1,true)and server:find("updateAttempts",1,true),"fleet update retry backoff missing")
assert(server:find("lastFleetSave",1,true)and server:find("FLEET_PROBE_MS=30000",1,true),"fleet registry/probe batching missing")
local client=read("roles/client.lua")
assert(client:find("SERVER_REPLY_MS=15000",1,true)and client:find("connectionAgeMs",1,true),"client connection truth timeout missing")
local admin=read("clients/admin_v29.lua")
assert(admin:find("CACHED DATA IS DISPLAY ONLY",1,true)and admin:find("plannedBuilderMonitor",1,true)and admin:find('sharedView=="BUILDER"',1,true),"adaptive Command Center Builder/telemetry UI missing")
local manifest=read("manifest.json")
assert(manifest:find("core/telemetry_health.lua",1,true)and manifest:find("clients/builder_dashboard.lua",1,true),"Alpha82 files are not update-managed")
assert(read("version.txt"):find("5.0.0-alpha.82",1,true),"Alpha82 version was not bumped")

print("alpha82 connected Builder overhaul smoke test OK")
