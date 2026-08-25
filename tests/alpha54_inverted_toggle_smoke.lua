local realPrint=print

colors={white=1,orange=2,lightGray=256,lime=32,red=16384,blue=2048,gray=128,black=32768}
local output=true
local wrote=false
local pulls=0

redstone={getOutput=function() return false end,setOutput=function() error("computer redstone should not be used") end}
peripheral={
  getNames=function() return {"redstone_integrator_0"} end,
  getType=function(name) return name=="redstone_integrator_0" and "redstone_integrator" or nil end,
  hasType=function() return false end,
  wrap=function() return nil end,
  getMethods=function(name)
    assert(name=="redstone_integrator_0")
    return {"getOutput","setOutput"}
  end,
  call=function(name,method,side,value)
    assert(name=="redstone_integrator_0","wrong integrator target")
    assert(side=="east","wrong integrator side")
    if method=="getOutput" then return output end
    if method=="setOutput" then output=value==true; wrote=true; return true end
    error("unexpected method "..tostring(method))
  end,
}
fs={exists=function() return true end,makeDir=function() end,open=function() return nil end}
term={setBackgroundColor=function()end,setTextColor=function()end,clear=function()end,setCursorPos=function()end}
textutils={}
sleep=function() end

os={
  getComputerID=function() return 54 end,
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
  localVersion=function() return "5.0.0-alpha.54" end,
  hasPendingProbation=function() return false end,
  markHealthy=function() return true end,
  fleetManaged=function() return true end,
} end

-- Inverted door truth: physical redstone ON means logical CLOSED.
local localState={doors={localDoors={{target="redstone_integrator_0",side="east",name="ROOM PANEL",kind="digital_side",mode="invert",signal=true,open=false}}}}
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
        local ok,res=action("__local_doors","toggle",{_source="54",target="redstone_integrator_0",side="east"})
        assert(ok==true,"inverted local toggle failed: "..tostring(res))
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
assert(wrote==true,"inverted monitor touch never wrote integrator output")
assert(output==false,"inverted CLOSED -> OPEN toggle must turn physical redstone OFF")
realPrint("alpha54 inverted toggle smoke test OK")
