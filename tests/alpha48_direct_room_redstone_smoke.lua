local realPrint=print

colors={white=1,orange=2,lightGray=256,lime=32,red=16384,blue=2048,gray=128,black=32768}
local output=false
local wrote=false
local pulls=0

redstone={
  getOutput=function(side) assert(side=="left","wrong getOutput side"); return output end,
  setOutput=function(side,value) assert(side=="left","wrong setOutput side"); output=value==true; wrote=true end,
}
peripheral={getNames=function() return {} end,getType=function() return nil end,hasType=function() return false end,wrap=function() return nil end,getMethods=function() return {} end}
fs={exists=function() return true end,makeDir=function() end,open=function() return nil end}
term={setBackgroundColor=function()end,setTextColor=function()end,clear=function()end,setCursorPos=function()end}
textutils={}
sleep=function() end

os={
  getComputerID=function() return 37 end,
  epoch=function() return 1000 end,
  startTimer=function() return 123 end,
  pullEvent=function()
    pulls=pulls+1
    if pulls==1 then return "monitor_touch","monitor_0",10,12 end
    error("STOP_TEST")
  end,
}

package.preload["core.network"]=function() return {
  openAll=function()end, advertise=function()end, findServer=function() return 1 end,
  send=function() return true end,
} end
package.preload["core.update_service"]=function() return {
  localVersion=function() return "5.0.0-alpha.48" end,
  hasPendingProbation=function() return false end,
  markHealthy=function() return true end,
  fleetManaged=function() return true end,
} end

local localState={doors={localDoors={{target="computer",side="left",name="ROOM PANEL",mode="hold",signal=false,open=false}}}}
local doorsModule={id="doors",read=function() return localState.doors end,handleCommand=function() error("GENERIC_DOORS_MUST_NOT_BE_CALLED") end}
package.preload["core.module_loader"]=function() return {
  discover=function() return {doors=doorsModule} end,
  readAll=function(_,prev) return localState end,
} end

package.preload["clients.wall"]=function()
  return {
    init=function()end,
    render=function() return true end,
    handleEvent=function(ev,env,action)
      if ev[1]=="monitor_touch" then
        local ok,res=action("__local_doors","toggle",{_source="37",target="computer",side="left"})
        assert(ok==true,"local direct action failed: "..tostring(res))
        return true
      end
      return false
    end,
  }
end
package.preload["clients.terminal"]=function() return {} end

package.loaded["roles.client"]=nil
local client=require("roles.client")
local ok,err=pcall(client.run,{profile="wall",name="Room",network={protocol="kimi_base_os_v1"}})
assert(ok==false and tostring(err):find("STOP_TEST",1,true),"client loop did not reach test stop")
assert(wrote==true,"monitor touch never wrote redstone")
assert(output==true,"monitor touch did not turn redstone ON")
realPrint("alpha48 direct room redstone smoke test OK")
