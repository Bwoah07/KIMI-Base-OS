local realPrint=print
colors={white=1,orange=2,magenta=4,lightBlue=8,yellow=16,lime=32,pink=64,gray=128,lightGray=256,cyan=512,purple=1024,blue=2048,brown=4096,green=8192,red=16384,black=32768}
local function surface(w,h)
 local rows,x,y={},1,1;local s={}
 s.setTextScale=function()end;s.setBackgroundColor=function()end;s.setTextColor=function()end
 s.clear=function()rows={};x,y=1,1 end;s.setCursorPos=function(nx,ny)x,y=nx,ny end;s.getSize=function()return w,h end
 s.write=function(v)v=tostring(v or"");if y<1 or y>h or x>w then return end;v=v:sub(1,math.max(0,w-x+1));local row=rows[y]or string.rep(" ",w);rows[y]=row:sub(1,x-1)..v..row:sub(x+#v);x=x+#v end
 s.output=function()local o={};for i=1,h do o[i]=rows[i]or string.rep(" ",w)end;return table.concat(o,"\n")end
 return s
end
local devices={};peripheral={}
peripheral.getNames=function()local o={};for n in pairs(devices)do o[#o+1]=n end;table.sort(o);return o end
peripheral.getType=function(n)return devices[n]and devices[n].type end
peripheral.hasType=function(n,t)return devices[n]and devices[n].type==t or false end
peripheral.wrap=function(n)return devices[n]and devices[n].object end
local mon=surface(42,24);devices.monitor={type="monitor",object=mon}
term=surface(26,20)
print=function()end
os={getComputerID=function()return 42 end,getComputerLabel=function()return"Front Gate"end,time=function()return 12.0 end,epoch=function()return 1000 end}
fs={exists=function()return false end,isDir=function()return false end,delete=function()end}

-- Alpha42's invariant is the crash-proof base room renderer. Newer setup
-- wrappers have their own regression tests and should not change this contract.
local room=require("clients.room_v12");room.init({name="KIMI-42"})
local sensors={{type="environment_detector",summary="plains",metrics={temperature=21.5}}}
local door={id="local:redstone_integrator_0|west",name="FRONT GATE",target="redstone_integrator_0",side="west",kind="digital_side",mode="hold",online=true,open=true,signal=true}
local meta={connected=true,localState={doors={localDoors={door},candidates={}},attachments={sensors={}}}}
local env={version="5.0.0-alpha.42",state={attachments={sensors=sensors}}}
local ok=room.render(env,meta);local out=mon.output()
assert(ok~=false,"normal room render failed")
assert(out:find("FRONT GATE",1,true),"door disappeared")
assert(out:find("REDSTONE ON",1,true),"redstone truth disappeared")
assert(out:find("CLOSE DOOR",1,true),"door action disappeared")
assert(out:find("BASE SENS 1",1,true) or out:find("BASE SENSORS 1",1,true),"base sensor fallback disappeared")

-- Force a render exception after the monitor has been discovered. The active
-- room renderer must paint the failure on-screen instead of silently going black.
local poison=setmetatable({}, {__len=function()error("synthetic sensor crash")end})
env.state.attachments.sensors=poison
local ok2,err2=room.render(env,meta);out=mon.output()
assert(ok2==false,"synthetic UI crash was not contained")
assert(out:find("KIMI UI ERROR",1,true),"UI crash left monitor blank")
assert(out:find("synthetic sensor crash",1,true),"on-screen UI error lost the real cause")

local f=assert(io.open("roles/client.lua","r"));local src=f:read("*a");f:close()
assert(src:find("paintUiError",1,true),"client-level UI crash guard missing")
assert(src:find("pcall(profile.render",1,true),"profile render is not protected")
local w=assert(io.open("clients/wall.lua","r"));local wall=w:read("*a");w:close()
assert(wall:find('require("clients.room_',1,true),"wall client is not routed to a dedicated room renderer")
realPrint("alpha42 crash-proof room smoke test OK")
