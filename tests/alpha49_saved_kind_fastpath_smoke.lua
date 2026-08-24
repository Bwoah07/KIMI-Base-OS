local realPrint=print
local output=false
package.loaded["core.doors_impl"]={handleCommand=function() error("GENERIC DOOR STACK MUST NOT RUN") end}
peripheral={
  call=function(name,method,...)
    local a={...}
    assert(name=="weird_redstone_controller","wrong target")
    if method=="setOutput" then assert(a[1]=="north","wrong side"); output=a[2]==true; return true end
    error("unsupported method "..tostring(method))
  end
}
redstone={}
sleep=function()end
local doors=assert(loadfile("modules/doors.lua"))()
local state={localDoors={{target="weird_redstone_controller",side="north",kind="digital_side",mode="hold",signal=false}}}
local result=doors.handleCommand("toggle",{target="weird_redstone_controller",side="north"},state)
assert(output==true,"alpha49 did not drive saved redstone target directly")
assert(result and result.direct==true and result.signal==true,"alpha49 direct result missing")
realPrint("alpha49 saved-kind fastpath smoke test OK")
