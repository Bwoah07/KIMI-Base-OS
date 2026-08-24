local realPrint=print
colors={white=1,orange=2,magenta=4,lightBlue=8,yellow=16,lime=32,pink=64,gray=128,lightGray=256,cyan=512,purple=1024,blue=2048,brown=4096,green=8192,red=16384,black=32768}
local function surface(w,h)local rows,x,y={},1,1;local s={};s.setTextScale=function()end;s.setBackgroundColor=function()end;s.setTextColor=function()end;s.clear=function()rows={};x,y=1,1 end;s.setCursorPos=function(nx,ny)x,y=nx,ny end;s.getSize=function()return w,h end;s.write=function(v)v=tostring(v or"");if y<1 or y>h or x>w then return end;v=v:sub(1,math.max(0,w-x+1));local row=rows[y]or string.rep(" ",w);rows[y]=row:sub(1,x-1)..v..row:sub(x+#v);x=x+#v end;s.output=function()local o={};for i=1,h do o[i]=rows[i]or string.rep(" ",w)end;return table.concat(o,"\n")end;return s end
local devices={};peripheral={};peripheral.getNames=function()local o={};for n in pairs(devices)do o[#o+1]=n end;table.sort(o);return o end;peripheral.hasType=function(n,t)return devices[n]and devices[n].type==t or false end;peripheral.wrap=function(n)return devices[n]and devices[n].object end
local mon=surface(42,24);devices.monitor={type="monitor",object=mon}
os={getComputerID=function()return 42 end,getComputerLabel=function()return"Front Gate"end,time=function()return 12.0 end,epoch=function()return 1000 end}
local room=assert(loadfile("clients/room_v10.lua"))();room.init({name="KIMI-42"})
local sensors={{type="environment_detector",summary="plains",metrics={temperature=21.5,biome="minecraft:plains"}},{type="player_detector",summary="2 online",metrics={onlinePlayers=2}},{type="geo_scanner",summary="ready",metrics={maxScanRadius=32}}}
local door={id="local:redstone_integrator_0|west",name="FRONT GATE",target="redstone_integrator_0",side="west",kind="digital_side",mode="hold",online=true,open=true,signal=true,inputSignal=false,inputReadable=true}
local meta={connected=true,localState={doors={localDoors={door},candidates={}},attachments={sensors={},devices={}}}}
local env={version="5.0.0-alpha.41",state={attachments={sensors=sensors},doors={doors={door}},fleet={[1]={online=true,version="5.0.0-alpha.41"},[42]={online=true,version="5.0.0-alpha.41"}}}}
room.render(env,meta);local out=mon.output()
assert(out:find("FRONT GATE",1,true),"door name missing")
assert(out:find("CLOSE DOOR",1,true),"live open door did not render CLOSE DOOR")
assert(out:find("REDSTONE ON",1,true),"live redstone signal missing")
assert(out:find("BASE SENS 3",1,true),"global sensor fallback missing")
assert(out:find("ENVIRONMENT",1,true),"base sensor telemetry not shown")
assert(not out:find("NOT CONNECTED",1,true),"legacy sensor-not-connected warning leaked")
local f=assert(io.open("roles/client.lua","r"));local src=f:read("*a");f:close();assert(src:find('n:match("^adaptive")',1,true),"legacy adaptive profile migration missing");assert(src:find('return "wall"',1,true),"legacy profile does not route to wall")
local adminMon=surface(68,30);devices.monitor.object=adminMon;os.getComputerLabel=function()return"Main Base"end
local admin=assert(loadfile("clients/admin_v10.lua"))();admin.init({name="Main Base"});local power={onlineSources=1,stored=900,capacity=1000,input=50,output=20,filledPercentage=.9,matrices={{stored=900,capacity=1000,input=50,output=20,filledPercentage=.9}}};env.state.power=power;env.state.fleet={[1]={online=true,version="5.0.0-alpha.41",name="Main Base"},[2]={online=true,version="5.0.0-alpha.41",name="Remote Node"}};admin.render(env,{localServer=true});out=adminMon.output();assert(out:find("ALL SYSTEMS NOMINAL",1,true),"clean command center health line missing");assert(out:find("HOME",1,true)and out:find("DOORS",1,true)and out:find("SENSORS",1,true),"command center navigation missing")
realPrint("alpha41 profile/sensor smoke test OK")
