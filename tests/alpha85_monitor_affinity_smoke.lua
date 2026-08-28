package.path="./?.lua;./?/init.lua;"..package.path

local function read(path)local f=assert(io.open(path,"r"));local s=f:read("*a");f:close();return s end

local setup=read("setup.lua")
assert(setup:find("TOUCH THIS SCREEN",1,true),"setup does not explicitly bind configuration to the touched monitor")
assert(setup:find("CHOOSE OTHER SCREEN",1,true),"setup cannot move deliberately to another monitor")
assert(setup:find('shell.run("door_setup",e.name)',1,true),"door setup is not pinned to the active setup monitor")
assert(setup:find("THIS SCREEN VIEW",1,true),"screen assignment is not scoped to the active monitor")
assert(setup:find('monitorConfig.set(data,e.name',1,true),"screen assignment can still mutate the wrong monitor")
assert(setup:find('if dirty then e.mon.clear();center(e,2,"APPLYING SETUP..."',1,true),"dirty setup can exit without applying monitor changes")

local door=read("door_setup.lua")
assert(door:find("requestedMonitor",1,true),"door setup does not accept a preferred monitor")
assert(door:find("chooseMonitor(ms,requestedMonitor)",1,true),"door setup can jump away from the requested monitor")
assert(door:find("NO DOOR CONTROLLERS FOUND",1,true),"empty door setup still renders as an unexplained blank screen")
assert(door:find("A MODEM DOES NOT OUTPUT REDSTONE",1,true),"empty door setup does not explain modem/redstone requirements")
assert(door:find("REFRESH",1,true),"door setup cannot refresh after a controller is attached")

print("alpha85 monitor affinity smoke test OK")
