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
local adminMon=surface(80,26);devices.monitor={type="monitor",object=adminMon}
os={getComputerID=function()return 1 end,getComputerLabel=function()return"Main Base"end,time=function()return 12.0 end,epoch=function()return 1000 end}

local admin=assert(loadfile("clients/admin_v10.lua"))();admin.init({name="KIMI-1"})
local power={onlineSources=1,stored=750,capacity=1000,input=50,output=20,filledPercentage=.75,matrices={{stored=750,capacity=1000,input=50,output=20,filledPercentage=.75}}}
local adminEnv={version="5.0.0-alpha.38",state={doors={doors={{name="FRONT GATE",online=true,open=false}}},attachments={sensors={},devices={},diagnostics={}},power=power,fleet={[1]={role="server",name="Main Base",version="5.0.0-alpha.38",online=true},[2]={role="node",name="Remote Node",version="5.0.0-alpha.38",online=true},[42]={role="client",name="Front Gate",version="5.0.0-alpha.38",online=true}},update={syncResult="DISCOVERING FLEET"}}}
admin.render(adminEnv,{connected=true,localServer=true,localState={power=power,attachments={sensors={}}}})
local out=adminMon.output()
assert(out:find("FLEET LOCKED 3/3",1,true),"overview still trusts stale discovering-fleet text")
assert(not out:find("DISCOVERING FLEET",1,true),"stale fleet-sync status leaked into overview")
assert(out:find("SENSOR BUS",1,true),"overview does not surface missing detector telemetry")

-- Door implementation must keep universal actuator modes. Do not depend on
-- formatting/minification: later releases intentionally rewrote the module.
local f=assert(io.open("modules/doors.lua","r")); local doorSource=f:read("*a"); f:close()
assert(doorSource:find('"pulse"',1,true) and doorSource:find('"toggle"',1,true),"pulse/toggle door mode missing")
assert(doorSource:find('"invert"',1,true),"inverted-hold door mode missing")
assert(doorSource:find('setAnalogOutput',1,true),"analog redstone actuator support missing")
assert(doorSource:find('setEnabled',1,true) and doorSource:find('setActive',1,true),"relay/piston actuator support missing")

realPrint("alpha38 lock-in smoke test OK")
