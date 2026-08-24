local realPrint=print
_G.unpack=nil
assert(type(table.unpack)=="function","Lua 5.2 table.unpack required")

local actual={north=false}
local staleNorth=false
peripheral={}
peripheral.getNames=function() return {"redstone_integrator_0"} end
peripheral.getType=function(name) return "redstone_integrator" end
peripheral.getMethods=function(name) return {"getOutput","setOutput","getInput"} end
peripheral.call=function(name,method,...)
  local a={...}
  if method=="getOutput" then
    local side=a[1]
    if side=="north" and staleNorth then staleNorth=false; return false end
    return actual[side] == true
  end
  if method=="getInput" then return false end
  if method=="setOutput" then
    assert(a[1]=="north","wrong side")
    actual.north=a[2]==true
    staleNorth=true -- emulate peripheral readback lagging one tick
    return true
  end
  error("unexpected peripheral method: "..tostring(method))
end
redstone={setOutput=function()end,getOutput=function()return false end,getInput=function()return false end}
fs={exists=function()return false end,isDir=function()return false end,makeDir=function()end,open=function()return nil end}
textutils={unserialize=function()return nil end,serialize=function()return "{}" end}
os={epoch=function()return 1000 end}
sleep=function()end

package.loaded["modules.doors"]=nil
package.loaded["core.doors_impl"]=nil
local doors=require("modules.doors")
assert(type(_G.unpack)=="function","door wrapper did not install Lua 5.2 unpack compatibility")
local snapshot=doors.read()
local found
for _,c in ipairs(snapshot.candidates or {}) do
  if c.target=="redstone_integrator_0" and c.side=="north" then found=c break end
end
assert(found,"integrator north candidate missing")

local result=doors.handleCommand("toggle",{target="redstone_integrator_0",side="north"})
assert(actual.north==true,"door output did not turn on")
assert(result and result.pending==true and result.propagationDelay==true,"one-tick readback lag was treated as a hard failure")

snapshot=doors.read()
local nowOn=false
for _,c in ipairs(snapshot.candidates or {}) do
  if c.target=="redstone_integrator_0" and c.side=="north" then nowOn=c.signal==true end
end
assert(nowOn,"next telemetry refresh did not see redstone ON")
realPrint("alpha47 CC/redstone propagation smoke test OK")
