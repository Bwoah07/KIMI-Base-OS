local realPrint=print
local realOs=os

colors={white=1,orange=2,lightBlue=8,lime=32,gray=128,lightGray=256,cyan=512,blue=2048,red=16384,black=32768}

-- ---------------------------------------------------------------------------
-- 1) Admin big screen exposes a real OPEN/CLOSE button for room-owned doors.
-- ---------------------------------------------------------------------------
local W,H=60,30
local rows={}
local cx,cy=1,1
local mon={}
function mon.setTextScale()end
function mon.getSize()return W,H end
function mon.setCursorPos(x,y)cx,cy=x,y end
function mon.setTextColor()end
function mon.setBackgroundColor()end
function mon.clear()rows={};cx,cy=1,1 end
function mon.write(v)
  v=tostring(v or"")
  local row=rows[cy]or string.rep(" ",W)
  v=v:sub(1,math.max(0,W-cx+1))
  rows[cy]=row:sub(1,cx-1)..v..row:sub(cx+#v)
  cx=cx+#v
end

peripheral={
 getNames=function()return{"monitor_0"}end,
 getType=function(n)return n=="monitor_0"and"monitor"or nil end,
 hasType=function(n,t)return n=="monitor_0"and t=="monitor"end,
 wrap=function(n)return n=="monitor_0"and mon or nil end,
}

os={
 epoch=function()return 1000 end,
 time=function()return 12 end,
 getComputerLabel=function()return"Main Base"end,
 getComputerID=function()return 1 end,
}

package.loaded["clients.admin_v15"]={
 init=function()return true end,
 render=function()return true end,
 handleEvent=function()return false end,
 onPeripheralChange=function()end,
}
package.loaded["clients.admin_v16"]=nil
local admin=assert(loadfile("clients/admin_v16.lua"))()
admin.init({name="Main Base"})

local function makeEnv(open)
 return{version="5.0.0-alpha.67",state={doors={doors={{
  id="local:42|redstone_integrator_0|east",key="42|redstone_integrator_0|east",
  name="ROOM PANEL",source="42",_source="42",target="redstone_integrator_0",side="east",
  open=open,online=true,mode="invert"
 }}}}}
end

local env=makeEnv(false)
admin.render(env,{connected=true})
local screen=table.concat(rows,"\n")
assert(screen:find("OPEN DOOR",1,true),"big screen did not render OPEN DOOR control")

local requested
local function action(module,cmd,args)
 requested={module=module,cmd=cmd,args=args}
 return{ok=true,result={queued=true,async=true}}
end

-- Home door control occupies the right half; first button is rows 8-9.
assert(admin.handleEvent({"monitor_touch","monitor_0",45,8},env,action)==true,"big-screen door tap was not consumed")
assert(requested and requested.module=="remote_doors_async","big screen did not use shared async door transport")
assert(requested.cmd=="open","closed door did not issue explicit OPEN")
assert(tostring(requested.args.source)=="42","big screen lost owning room computer")
assert(requested.args.target=="redstone_integrator_0"and requested.args.side=="east","big screen lost actuator identity")
assert(requested.args._source==nil,"big screen used reserved _source and would bypass async bridge")

-- Feed confirmed OPEN telemetry and verify the same button now sends CLOSE.
os.epoch=function()return 1100 end
env=makeEnv(true)
admin.render(env,{connected=true})
requested=nil
assert(admin.handleEvent({"monitor_touch","monitor_0",45,8},env,action)==true,"open-door big-screen tap was not consumed")
assert(requested and requested.cmd=="close","open door did not issue explicit CLOSE")

-- ---------------------------------------------------------------------------
-- 2) Local Command Center module bridge must enter server_v3 async manager.
--    It must return immediately after scheduling attempt #1; no ACK wait here.
-- ---------------------------------------------------------------------------
local sends={}
local timerSeq=700
package.loaded["core.network"]={
 send=function(target,cfg,kind,payload)
  sends[#sends+1]={target=target,kind=kind,payload=payload}
  return true
 end
}
package.loaded["roles.server_v2"]={
 run=function(cfg)
  package.loaded["modules.remote_doors_async"]=nil
  local bridge=assert(loadfile("modules/remote_doors_async.lua"))()
  local result=bridge.handleCommand("open",{source="42",target="redstone_integrator_0",side="east"})
  assert(type(result)=="table"and result.queued==true and result.async==true,"local Command Center did not start async transaction")
  assert(result.requestId,"async local door transaction has no requestId")
  return true
 end
}

os={
 getComputerID=function()return 1 end,
 epoch=function()return 2000 end,
 startTimer=function()timerSeq=timerSeq+1;return timerSeq end,
 cancelTimer=function()end,
 pullEvent=function()error("local async bridge blocked waiting for an event",0)end,
}

package.loaded["roles.server_v3"]=nil
local server=assert(loadfile("roles/server_v3.lua"))()
assert(server.run({network={protocol="kimi-test"}})==true,"server_v3 local bridge did not return cleanly")

local sent
for _,s in ipairs(sends)do if s.target==42 and s.kind=="module.command"then sent=s break end end
assert(sent,"local big-screen transaction never sent module.command to room 42")
assert(sent.payload.module=="doors"and sent.payload.action=="open","local transaction sent wrong destination command")
assert(sent.payload.requestId,"local transaction did not attach requestId")
assert(tostring(sent.payload.args._source)=="42","destination ownership _source missing")

os=realOs
realPrint("alpha67 big-screen door controls smoke test OK")
