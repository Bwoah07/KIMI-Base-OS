-- PR CI verification for alpha50 configured-door dispatch.
local realPrint=print

local calls={}
peripheral={}
peripheral.call=function(name,method,...)
  calls[#calls+1]={name=name,method=method,args={...}}
  if method=="setOpen" then return true end
  error("unsupported method "..tostring(method))
end
redstone={setOutput=function()end,getOutput=function() return false end,getInput=function() return false end}
fs={exists=function()return false end,isDir=function()return false end,makeDir=function()end,open=function()return nil end}
textutils={unserialize=function()return nil end,serialize=function()return "{}" end}
os={epoch=function()return 1000 end}
sleep=function()end

package.loaded["core.doors_impl"]={
  id="doors",
  read=function() return {} end,
  handleCommand=function() error("GENERIC CORE MUST NOT RUN") end,
}
package.loaded["modules.doors"]=nil
local doors=require("modules.doors")

local state={localDoors={{target="door_controller_0",side=nil,kind="native_door",mode="hold",signal=false,open=false}}}
local result=doors.handleCommand("toggle",{target="door_controller_0",side=nil},state)
assert(result and result.direct==true,"configured native door did not use direct path")
assert(calls[1] and calls[1].method=="setOpen","native door did not call setOpen")
assert(calls[1].args[1]==true,"native door did not request open=true")

calls={}
peripheral.call=function(name,method,...)
  calls[#calls+1]={name=name,method=method,args={...}}
  if method=="setOutput" then return true end
  error("unexpected method "..tostring(method))
end
state={localDoors={{target="redstone_integrator_0",side="north",kind="digital_side",mode="hold",signal=false,open=false}}}
result=doors.handleCommand("toggle",{target="redstone_integrator_0",side="north"},state)
assert(result and result.direct==true,"configured digital door did not use direct path")
assert(calls[1] and calls[1].method=="setOutput","digital door did not call setOutput")
assert(calls[1].args[1]=="north" and calls[1].args[2]==true,"digital door arguments wrong")

realPrint("alpha50 configured door dispatch smoke test OK")
