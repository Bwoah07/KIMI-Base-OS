local realPrint=print

colors={black=1,white=2,lightGray=3,lime=4,orange=5,red=6,blue=7,gray=8}
local writes={}
local mon={
  setTextScale=function()end,setBackgroundColor=function()end,setTextColor=function()end,clear=function()end,
  setCursorPos=function()end,write=function(s) writes[#writes+1]=tostring(s) end,getSize=function() return 42,24 end
}
peripheral={
  getNames=function() return {"monitor_0"} end,
  getType=function() return "monitor" end,
  hasType=function() return true end,
  wrap=function() return mon end,
}
local flag=false
fs={
  exists=function(path) return path==".kimi/door_setup_request" and flag or false end,
  isDir=function() return false end,
  delete=function(path) if path==".kimi/door_setup_request" then flag=false end end,
  makeDir=function()end,
  open=function(path,mode)
    if path==".kimi/door_setup_request" and mode=="w" then
      return {writeLine=function() flag=true end,close=function()end}
    end
    return nil
  end,
}
os={
  getComputerLabel=function() return "ROOM PANEL" end,
  getComputerID=function() return 7 end,
  time=function() return 12 end,
  reboot=function() _G.__rebooted=true end,
}
sleep=function()end
term={setBackgroundColor=function()end,setTextColor=function()end,clear=function()end,setCursorPos=function()end}

package.loaded["clients.room_v12"]={init=function()end,render=function() return true end,handleEvent=function() return false end}
package.loaded["clients.room_v14"]=nil
local ui=require("clients.room_v14")

local meta={localState={doors={localDoors={},candidates={{target="computer",side="left",type="computer_redstone",controller="THIS COMPUTER"}}}}}
local calls={}
local function action(mod,act,args)
  calls[#calls+1]={mod=mod,act=act,args=args}
  return true,{ok=true}
end

ui.init({})
ui.render({},meta)
local ok=ui.handleEvent({"monitor_touch","monitor_0",5,11},{},action)
assert(ok==true,"actuator selection did not advance wizard")
assert(#calls==0,"door was saved before logic choice")
ok=ui.handleEvent({"monitor_touch","monitor_0",25,13},{},action)
assert(ok==true,"inverted selection failed")
assert(calls[1] and calls[1].act=="register_local","door was not registered")
assert(calls[2] and calls[2].act=="configure_local","invert mode was not saved")
assert(calls[2].args.mode=="invert","wrong setup mode saved")

-- door setup shell command creates a request and reboots.
flag=false; _G.__rebooted=false
local chunk=assert(loadfile("door.lua"))
chunk("setup")
assert(flag==true,"door setup command did not create setup request")
assert(_G.__rebooted==true,"door setup command did not reboot")

realPrint("alpha52 setup wizard smoke test OK")
