local realPrint=print
colors={white=1,orange=2,magenta=4,lightBlue=8,yellow=16,lime=32,pink=64,gray=128,lightGray=256,cyan=512,purple=1024,blue=2048,brown=4096,green=8192,red=16384,black=32768}

local function read(path)local f=assert(io.open(path,"r"));local s=f:read("*a");f:close();return s end
local updater=read("updater.lua")
assert(updater:find("sameBody",1,true),"updater no longer skips unchanged files")
assert(updater:find("delta:",1,true),"updater no longer reports delta staging")
assert(updater:find("clearPath(BACKUP)",1,true),"stale rollback is not cleared before a stable update")
assert(not updater:find("listUnion",1,true),"old full-OS backup algorithm returned")
local us=read("core/update_service.lua")
assert(us:find("fs.delete(ROLLBACK)",1,true),"healthy probation does not release rollback disk space")
local ds=read("modules/doors.lua")
assert(ds:find("getInput",1,true),"digital redstone input feedback missing")
assert(ds:find("getAnalogInput",1,true) or ds:find("getAnalogueInput",1,true),"analog redstone input feedback missing")
assert(ds:find("feedbackSide",1,true),"door feedback-signal configuration missing")
assert(ds:find("signal=",1,true),"door telemetry does not expose live redstone signal")

local function surface(w,h)
 local rows,x,y={},1,1;local s={}
 s.setTextScale=function()end;s.setBackgroundColor=function()end;s.setTextColor=function()end;s.clear=function()rows={};x,y=1,1 end;s.setCursorPos=function(a,b)x,y=a,b end;s.getSize=function()return w,h end
 s.write=function(v)v=tostring(v or"");if y<1 or y>h or x>w then return end;v=v:sub(1,math.max(0,w-x+1));local row=rows[y]or string.rep(" ",w);rows[y]=row:sub(1,x-1)..v..row:sub(x+#v);x=x+#v end
 s.output=function()local out={};for i=1,h do out[i]=rows[i]or string.rep(" ",w)end;return table.concat(out,"\n")end
 return s
end
local devices={};peripheral={}
peripheral.getNames=function()local a={};for n in pairs(devices)do a[#a+1]=n end;table.sort(a);return a end
peripheral.hasType=function(n,t)return devices[n]and devices[n].type==t or false end
peripheral.wrap=function(n)return devices[n]and devices[n].object end
term={}
os={getComputerLabel=function()return"Main Base"end,getComputerID=function()return 1 end,time=function()return 21.5 end,epoch=function()return 1 end}
local main=surface(68,30);local left=surface(25,30);local right=surface(25,30)
devices.main={type="monitor",object=main};devices.left={type="monitor",object=left};devices.right={type="monitor",object=right}
local admin=assert(loadfile("clients/admin_v9.lua"))();admin.init({name="Main Base"})
local power={onlineSources=1,stored=900,capacity=1000,input=40,output=25,filledPercentage=.9}
local env={version="5.0.0-alpha.40",state={power=power,attachments={sensors={{type="environment_detector",summary="plains"}}},doors={doors={{name="FRONT GATE",open=false,online=true}}},fleet={[1]={name="Main Base",role="server",online=true,version="5.0.0-alpha.40"},[2]={name="Room Panel",role="client",online=true,version="5.0.0-alpha.40"},[3]={name="Remote Node",role="node",online=true,version="5.0.0-alpha.40"}}}}
admin.render(env,{localServer=true})
local out=main.output()
assert(out:find("COMMAND CENTER",1,true),"main dashboard title missing")
assert(out:find("3/3",1,true),"fleet lock summary missing")
assert(out:find("HOME",1,true) and out:find("DOORS",1,true) and out:find("POWER",1,true),"clean persistent navigation missing")
assert(out:find("ALL SYSTEMS NOMINAL",1,true),"healthy system status missing")
assert(left.output():find("POWER",1,true),"second monitor was not auto-populated with power")
assert(right.output():find("FLEET",1,true),"third monitor was not auto-populated with fleet")

realPrint("alpha40 lock-in smoke test OK")
