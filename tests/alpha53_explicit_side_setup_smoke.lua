local realPrint=print

colors={black=1,white=2,lightGray=3,lime=4,orange=5,red=6,blue=7,gray=8}
local mon={x=1,y=1,writes={}}
function mon.setTextScale() end
function mon.setBackgroundColor() end
function mon.setTextColor() end
function mon.clear() mon.writes={} end
function mon.setCursorPos(x,y) mon.x,mon.y=x,y end
function mon.write(s) mon.writes[#mon.writes+1]={x=mon.x,y=mon.y,text=tostring(s)} end
function mon.getSize() return 42,24 end

peripheral={
  getNames=function() return {"monitor_0"} end,
  getType=function() return "monitor" end,
  hasType=function() return true end,
  wrap=function() return mon end,
}
fs={exists=function() return false end,isDir=function() return false end,delete=function() end}
os={getComputerID=function() return 7 end,getComputerLabel=function() return "ROOM PANEL" end,time=function() return 12 end}
term={setBackgroundColor=function()end,setTextColor=function()end,clear=function()end,setCursorPos=function()end}

package.loaded["clients.room_v12"]={init=function()end,render=function() return true end,handleEvent=function() return false end}
package.loaded["clients.room_v15"]=nil
local ui=require("clients.room_v15")

local candidates={}
for _,side in ipairs({"north","south","east","west","up","down"}) do
  candidates[#candidates+1]={target="redstone_integrator_0",side=side,type="redstone_integrator",controller="REDSTONE INTEGRATOR",kind="digital_side",priority=1}
end
for _,side in ipairs({"top","bottom","left","right","front","back"}) do
  candidates[#candidates+1]={target="computer",side=side,type="computer_redstone",controller="THIS COMPUTER",kind="digital_side",priority=9}
end
local meta={localState={doors={localDoors={},candidates=candidates}}}
local calls={}
local function action(mod,act,args)
  calls[#calls+1]={mod=mod,act=act,args=args}
  return true,{ok=true}
end

ui.init({})
ui.render({},meta)

-- Step 1: choose the dedicated controller. Nothing may be saved yet.
local ok=ui.handleEvent({"monitor_touch","monitor_0",5,10},{},action)
assert(ok==true,"controller selection failed")
assert(#calls==0,"controller selection saved a door too early")

-- Step 2: choose EAST, the third side in the 3-column grid.
ok=ui.handleEvent({"monitor_touch","monitor_0",30,11},{},action)
assert(ok==true,"output-side selection failed")
assert(#calls==0,"side selection saved a door before logic choice")

-- Step 3: choose INVERTED and verify the exact chosen side is saved.
ok=ui.handleEvent({"monitor_touch","monitor_0",25,13},{},action)
assert(ok==true,"logic selection failed")
assert(calls[1] and calls[1].act=="register_local","door was not registered")
assert(calls[1].args.target=="redstone_integrator_0","wrong controller was saved")
assert(calls[1].args.side=="east","explicit output side was lost")
assert(calls[2] and calls[2].act=="configure_local","invert mode was not configured")
assert(calls[2].args.side=="east" and calls[2].args.mode=="invert","mode configuration lost selected side")

realPrint("alpha53 explicit side setup smoke test OK")
