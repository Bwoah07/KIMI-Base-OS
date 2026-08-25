local realPrint=print

-- Main Base must prefer the room computer's configured LOGICAL door state over
-- the raw redstone candidate signal. This is critical for inverted doors.
os={epoch=function()return 1000 end,getComputerLabel=function()return"Pocket"end,getComputerID=function()return 77 end,time=function()return 12 end}
fs={exists=function()return false end,isDir=function()return false end}
textutils={}

package.loaded["core.door_registry"]=nil
local registry=assert(loadfile("core/door_registry.lua"))()

local function aggregate(open,physical)
  local values={{sourceId="42",value={
    candidates={{target="redstone_integrator_0",side="east",label="east",controller="redstone_integrator_0",type="redstone_integrator",kind="digital_side",signal=physical,readable=true,localConfigured=true,localName="ROOM PANEL"}},
    localDoors={{id="local:redstone_integrator_0|east",key="redstone_integrator_0|east",name="ROOM PANEL",target="redstone_integrator_0",side="east",kind="digital_side",mode="invert",open=open,signal=physical,stateSource="output",online=true,localConfigured=true}}
  }}}
  local candidates=registry.candidates(values)
  assert(#candidates==1,"expected one candidate")
  assert(candidates[1].open==open,"registry lost logical open state")
  assert(candidates[1].mode=="invert","registry lost configured invert mode")
  local snap=registry.snapshot({},candidates)
  assert(#snap.doors==1,"configured room door disappeared from snapshot")
  assert(snap.doors[1].open==open,"snapshot did not preserve logical door state")
  return snap
end

-- Inverted physical OFF means logical OPEN.
local opened=aggregate(true,false)
-- Inverted physical ON means logical CLOSED.
local closed=aggregate(false,true)
assert(opened.doors[1].open==true and closed.doors[1].open==false,"inverted logical states collapsed")

-- Now prove the Pocket still issues the correct reverse action AFTER its 10s
-- optimistic shadow has expired, using the corrected Main Base telemetry.
colors={white=1,orange=2,lightBlue=8,lime=32,gray=128,lightGray=256,cyan=512,blue=2048,red=16384,black=32768}
keys={left=203,right=205,one=2,two=3,three=4,four=5,five=6,six=7,seven=8,eight=9,nine=10}
local W,H=26,20;local rows,x,y={},1,1
term={getSize=function()return W,H end,setCursorPos=function(a,b)x,y=a,b end,setTextColor=function()end,setBackgroundColor=function()end,clear=function()rows={};x,y=1,1 end}
term.write=function(v)v=tostring(v or"");local row=rows[y]or string.rep(" ",W);v=v:sub(1,math.max(0,W-x+1));rows[y]=row:sub(1,x-1)..v..row:sub(x+#v);x=x+#v end

local now=1000
os.epoch=function()return now end
package.loaded["clients.pocket_v5"]=nil;package.loaded["clients.pocket"]=nil
local pocket=assert(loadfile("clients/pocket.lua"))();pocket.init({})

local function envFrom(snap)
  return {version="5.0.0-alpha.64",state={doors=snap,power={},attachments={sensors={}},fleet={}}}
end

local firstEnv=envFrom(closed)
pocket.render(firstEnv,{connected=true})
local first
assert(pocket.handleEvent({"mouse_click",1,5,12},firstEnv,function(module,action,args)first={module=module,action=action,args=args};return true end)==true,"first Pocket tap not consumed")
assert(first and first.action=="open","closed door did not send OPEN")

-- Eleven seconds later the optimistic shadow is gone. Main Base telemetry now
-- correctly says OPEN, so the next tap MUST send CLOSE instead of OPEN again.
now=12001
local laterEnv=envFrom(opened)
pocket.onState(laterEnv)
pocket.render(laterEnv,{connected=true})
local second
assert(pocket.handleEvent({"mouse_click",1,5,12},laterEnv,function(module,action,args)second={module=module,action=action,args=args};return true end)==true,"second Pocket tap not consumed")
assert(second and second.action=="close","after shadow expiry Pocket did not trust logical OPEN telemetry and send CLOSE")
assert(second.args and tostring(second.args.source)=="42","Pocket lost room owner after long-running state refresh")

realPrint("alpha64 persistent logical door state smoke test OK")