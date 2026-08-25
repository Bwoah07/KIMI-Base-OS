local realPrint=print

-- Configured inverted door must convert logical OPEN to physical redstone OFF.
package.loaded["core.doors_impl"]={handleCommand=function()error("configured door fell into core fallback")end}
local writes={}
redstone={setOutput=function(side,value)writes[#writes+1]={side=side,value=value}end}
peripheral={call=function()error("peripheral path should not be used")end}
sleep=function()end
local doors=assert(loadfile("modules/doors.lua"))()
local state={localDoors={{target="computer",side="left",kind="digital_side",mode="invert",open=false,signal=true,pulseSeconds=.5}}}
local result=doors.handleCommand("open",{target="computer",side="left"},state)
assert(#writes==1,"inverted OPEN did not write redstone")
assert(writes[1].side=="left" and writes[1].value==false,"inverted OPEN must drive physical redstone OFF")
assert(result and result.open==true and result.signal==false,"configured door result lost logical/physical state")

-- Remote control running on the owning room computer must load and pass the saved local door state.
local sentinel={localDoors={{target="computer",side="left",mode="invert"}}}
package.loaded["modules.doors"]={
  read=function()return sentinel end,
  handleCommand=function(action,args,seen)
    assert(action=="open","remote action changed")
    assert(seen==sentinel,"remote door path discarded saved local door state")
    return{open=true,signal=false}
  end
}
package.loaded["core.network"]={send=function()error("local owner should not network-hop again")end}
package.loaded["core.config"]={load=function()return{network={protocol="kimi_base_os_v1"}}end}
os={getComputerID=function()return 42 end,epoch=function()return 1000 end}
package.loaded["modules.remote_doors"]=nil
local remote=assert(loadfile("modules/remote_doors.lua"))()
local r=remote.handleCommand("open",{_source="42",target="computer",side="left"})
assert(r and r.open==true and r.signal==false,"remote owner result incorrect")

realPrint("alpha58 remote inverted door smoke test OK")
