local realPrint=print
_G.unpack=nil
assert(type(table.unpack)=="function","Lua 5.2 table.unpack required")

local outputState=false
peripheral={}
peripheral.getNames=function() return {"redstone_integrator_0"} end
peripheral.getType=function(name) return "redstone_integrator" end
peripheral.getMethods=function(name) return {"getOutput","setOutput","getInput"} end
peripheral.call=function(name,method,...)
  local a={...}
  if method=="getOutput" then return outputState end
  if method=="getInput" then return false end
  if method=="setOutput" then
    assert(a[1]=="north","wrong side")
    outputState=a[2]==true
    return true
  end
  error("unexpected peripheral method: "..tostring(method))
end
redstone={setOutput=function()end,getOutput=function()return false end,getInput=function()return false end}
fs={exists=function()return false end,isDir=function()return false end,makeDir=function()end,open=function()return nil end}
textutils={unserialize=function()return nil end,serialize=function()return "{}" end}
os={epoch=function()return 1000 end}
sleep=function()end

package.loaded["core.doors_impl"]=nil
local doors=require("core.doors_impl")
local snapshot=doors.read({}, {})
local found
for _,c in ipairs(snapshot.candidates or {}) do
  if c.target=="redstone_integrator_0" and c.side=="north" then found=c break end
end
assert(found,"integrator north candidate missing")
local result=doors.handleCommand("toggle",{target="redstone_integrator_0",side="north"})
assert(outputState==true,"door output did not turn on")
assert(result and result.signal==true,"door result did not report signal on")
realPrint("alpha47 CC unpack door smoke test OK")
