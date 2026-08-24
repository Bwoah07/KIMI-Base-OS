local realPrint = print

colors = { black=1, white=2, orange=4, gray=8 }
local writes = {}
local mon = {}
function mon.setBackgroundColor(v) end
function mon.setTextColor(v) end
function mon.setCursorPos(x,y) mon.x,mon.y=x,y end
function mon.write(s) writes[#writes+1]={x=mon.x,y=mon.y,text=tostring(s)} end
function mon.getSize() return 42,24 end

peripheral = {}
peripheral.getNames = function() return {"monitor_0"} end
peripheral.getType = function(name) return name=="monitor_0" and "monitor" or "unknown" end
peripheral.hasType = function(name,t) return name=="monitor_0" and t=="monitor" end
peripheral.wrap = function(name) assert(name=="monitor_0"); return mon end

os = { getComputerID=function() return 77 end }

package.loaded["clients.room_v12"] = {
  init=function() end,
  render=function() return true end,
  handleEvent=function() return false end,
}
package.loaded["clients.room_v13"] = nil
local room = require("clients.room_v13")

local door = { target="redstone_integrator_0", side="north", mode="hold", supportsModes=true }
local meta = { localState={ doors={ localDoors={door} } } }
room.init({})
assert(room.render({},meta)==true,"room v13 render failed")

local sawOff=false
for _,w in ipairs(writes) do if w.text:find("INVERT: OFF",1,true) then sawOff=true end end
assert(sawOff,"invert OFF control was not rendered")

local called
local ok = room.handleEvent({"monitor_touch","monitor_0",21,20},{},function(module,action,args)
  called={module=module,action=action,args=args}
  return true,{ok=true}
end)
assert(ok==true,"invert touch did not succeed")
assert(called and called.module=="__local_doors","invert used wrong module")
assert(called.action=="configure_local","invert did not use configure_local")
assert(called.args.mode=="invert","invert did not switch mode to invert")
assert(called.args.target=="redstone_integrator_0" and called.args.side=="north","invert lost door actuator identity")
assert(called.args._source=="77","invert did not preserve local ownership")
assert(door.mode=="invert","local door mode did not update after successful action")

writes={}
room.render({},meta)
local sawOn=false
for _,w in ipairs(writes) do if w.text:find("INVERT: ON",1,true) then sawOn=true end end
assert(sawOn,"invert ON control was not rendered")

called=nil
room.handleEvent({"monitor_touch","monitor_0",21,20},{},function(module,action,args)
  called={module=module,action=action,args=args}; return true,{}
end)
assert(called and called.args.mode=="hold","second invert touch did not return to hold mode")

realPrint("alpha51 invert option smoke test OK")
