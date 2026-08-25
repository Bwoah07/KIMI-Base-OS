local realPrint=print

colors={black=1,white=2,lightGray=3,lime=4,orange=5,red=6,blue=7,gray=8}
local writes={}
local mon={
  setTextScale=function()end,setBackgroundColor=function()end,setTextColor=function()end,clear=function()end,
  setCursorPos=function()end,write=function(s) writes[#writes+1]=tostring(s) end,getSize=function() return 42,24 end,
}
peripheral={
  getNames=function() return {"monitor_0"} end,
  getType=function() return "monitor" end,
  hasType=function() return true end,
  wrap=function() return mon end,
}
fs={exists=function() return false end,isDir=function() return false end}
os={
  getComputerLabel=function() return "ROOM PANEL" end,
  getComputerID=function() return 7 end,
  time=function(kind) assert(kind=="ingame"); return 21.25 end,
}
term={setBackgroundColor=function()end,setTextColor=function()end,clear=function()end,setCursorPos=function()end}
print=function(...) end

package.loaded["clients.room_v16"]=nil
package.loaded["clients.room_v17"]=nil
package.loaded["clients.wall"]=nil
local ui=require("clients.wall")
local meta={connected=true,localState={doors={localDoors={{id="local:x",name="ROOM PANEL",target="computer",side="left",mode="invert",open=false,signal=true,online=true}}}}}
local env={state={environment={online=true,weather="RAINING"}}}
ui.init({name="ROOM PANEL"})
assert(ui.render(env,meta)==true,"room weather render failed")
local text=table.concat(writes,"\n")
assert(text:find("NIGHT",1,true),"night state missing")
assert(text:find("RAINING",1,true),"weather state missing")
assert(text:find("OPEN DOOR",1,true),"door action missing")
assert(not text:find("BIOME",1,true),"biome leaked into room screen")
assert(not text:find("REDSTONE",1,true),"redstone diagnostic leaked into room screen")
assert(not text:find("INPUT",1,true),"input diagnostic leaked into room screen")
assert(not text:find("BASE SENS",1,true),"base sensor count leaked into room screen")
assert(not text:find("SENSORS",1,true),"sensor footer leaked into room screen")

print=realPrint
realPrint("alpha55 clean room weather smoke test OK")
