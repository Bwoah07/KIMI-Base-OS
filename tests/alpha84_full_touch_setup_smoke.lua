package.path="./?.lua;./?/init.lua;"..package.path

local realPrint=print
colors={black=1,white=2,lightGray=3,lime=4,red=5,gray=6,blue=7,orange=8}
local writes={}
local mon={}
function mon.setBackgroundColor()end
function mon.setTextColor()end
function mon.clear()writes={}end
function mon.setCursorPos()end
function mon.write(v)writes[#writes+1]=tostring(v)end

package.loaded["core.touch_input"]=nil
local touch=require("core.touch_input")
assert(touch.sanitize(" Main@Base! ",28)=="MainBase","touch input sanitizer changed unexpectedly")
local boxes,err=touch.layout(60,24);assert(boxes,err)
local byId={};for _,b in ipairs(boxes)do byId[b.id]=b end
for _,id in ipairs({"char:K","char:I","char:M","space","back","clear","save","cancel"})do assert(byId[id],"missing touch keyboard control "..id)end

local function touchEvent(id)
 local b=assert(byId[id]);return{"monitor_touch","monitor_0",math.floor((b.x1+b.x2)/2),math.floor((b.y1+b.y2)/2)}
end
local queue={touchEvent("char:K"),touchEvent("char:I"),touchEvent("char:M"),touchEvent("char:I"),touchEvent("space"),touchEvent("char:M"),touchEvent("char:A"),touchEvent("char:I"),touchEvent("char:N"),touchEvent("save")}
local oldPull=os.pullEvent
os.pullEvent=function()local ev=table.remove(queue,1);assert(ev,"touch keyboard requested unexpected extra event");return table.unpack(ev)end
local value,ok=touch.read({name="monitor_0",mon=mon,w=60,h=24},{title="NAME",value="",maxLen=28})
os.pullEvent=oldPull
assert(ok==true and value=="KIMI MAIN","touch keyboard did not produce expected computer name")

local function read(path)local f=assert(io.open(path,"r"));local s=f:read("*a");f:close();return s end
local setup=read("setup.lua")
assert(setup:find('require("core.touch_input")',1,true),"setup does not use shared touch keyboard")
assert(setup:find("COMPUTER NAME",1,true)and(setup:find("SCREEN ASSIGNMENTS",1,true)or setup:find("THIS SCREEN VIEW",1,true))and setup:find("DOOR SETUP",1,true),"touch setup hub is incomplete")
assert(setup:find("REBOOT / APPLY",1,true),"touch setup hub has no apply/reboot path")
local door=read("door_setup.lua")
assert(door:find('require("core.touch_input")',1,true)and door:find("readNameTouch",1,true),"door naming still leaves the monitor")
assert(door:find("name=name,mode=mode",1,true),"touch door rename is not persisted through configure_local")
local installer=read("installer.lua")
assert(installer:find("Computer naming + monitor assignment will continue on the touchscreen",1,true),"fresh monitor install still requires terminal naming")
assert(installer:find('shell.run("setup")',1,true),"fresh install does not enter full touchscreen setup")

realPrint("alpha84 full touchscreen setup smoke test OK")
