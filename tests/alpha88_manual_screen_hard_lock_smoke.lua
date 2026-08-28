package.path="./?.lua;./?/init.lua;"..package.path

local function ok(v,msg)if not v then error("alpha88: "..tostring(msg),0)end end
local function read(path)local f=assert(io.open(path,"r"));local s=f:read("*a");f:close();return s end

-- Reproduce the live failure class: the running manual dashboard cached FLEET,
-- setup changed the saved map to DOORS, and the next frame must use DOORS
-- without requiring a process restart.
local diskView="fleet"
local cachedView="fleet"
local paints={}
package.loaded["clients.manual_dashboard"]={
    reload=function()cachedView=diskView;return{assignments={monitor_0=cachedView}}end,
    init=function()cachedView=diskView end,
    render=function()paints[#paints+1]=cachedView;return cachedView end,
    handleEvent=function()return false end,
    hasManualAssignments=function()return cachedView~="auto"end,
}
package.loaded["clients.manual_dashboard_v2"]=nil
local liveManual=require("clients.manual_dashboard_v2")
liveManual.init({})
ok(cachedView=="fleet","test did not begin with stale FLEET cache")
diskView="doors"
local painted=liveManual.render({},{})
ok(painted=="doors"and paints[#paints]=="doors","saved DOORS assignment did not replace stale cached FLEET view live")

-- Hard peripheral ownership: adaptive code must not be able to rediscover or
-- directly operate the pinned monitor through any common peripheral route.
package.loaded["core.monitor_config"]={
    load=function()return{assignments={monitor_0="doors",monitor_1="auto"}}end,
    normalizeView=function(v)return tostring(v or"auto"):lower()end,
}
local objects={monitor_0={name="monitor_0"},monitor_1={name="monitor_1"},geoScanner_0={name="geoScanner_0"}}
local originalGetNames=function()return{"monitor_0","monitor_1","geoScanner_0"}end
local originalWrap=function(name)return objects[name]end
local originalCall=function(name,method)return name..":"..method end
local originalFind=function()return objects.monitor_0,objects.monitor_1 end
local originalGetType=function(name)return tostring(name):match("^monitor_")and"monitor"or"geo_scanner"end
local originalHasType=function(name,wanted)return originalGetType(name)==wanted end
_G.peripheral={
    getNames=originalGetNames,wrap=originalWrap,call=originalCall,find=originalFind,
    getType=originalGetType,hasType=originalHasType,
}
package.loaded["core.monitor_authority"]=nil
local authority=require("core.monitor_authority")
local seen,wrapped,callWorked,found
authority.withAutomaticMonitorsHidden(function()
    seen=peripheral.getNames()
    wrapped=peripheral.wrap("monitor_0")
    callWorked=pcall(peripheral.call,"monitor_0","clear")
    found={peripheral.find("monitor")}
end)
local names={};for _,n in ipairs(seen or{})do names[n]=true end
ok(not names.monitor_0,"pinned DOORS monitor remained enumerable")
ok(names.monitor_1 and names.geoScanner_0,"AUTO monitor or non-monitor peripheral was incorrectly hidden")
ok(wrapped==nil,"adaptive code could still wrap pinned DOORS monitor")
ok(callWorked==false,"adaptive code could still peripheral.call pinned DOORS monitor")
ok(#found==1 and found[1]==objects.monitor_1,"peripheral.find rediscovered pinned DOORS monitor")
ok(peripheral.getNames==originalGetNames and peripheral.wrap==originalWrap and peripheral.call==originalCall and peripheral.find==originalFind,"peripheral API was not restored after guard")

-- The guard must restore the API even when old adaptive code explodes.
local survived=pcall(function()authority.withAutomaticMonitorsHidden(function()error("legacy UI exploded")end)end)
ok(not survived,"authority swallowed adaptive renderer error")
ok(peripheral.getNames==originalGetNames and peripheral.wrap==originalWrap and peripheral.call==originalCall and peripheral.find==originalFind,"peripheral API was not restored after adaptive error")

-- Runtime lineage contracts: both Command Center and remote wall clients must
-- hide pinned monitors from init onward and use the live-reloading dashboard.
local admin=read("clients/admin_v32.lua")
local room=read("clients/room_v19.lua")
local auth=read("core/monitor_authority.lua")
ok(admin:find('require("clients.manual_dashboard_v2")',1,true),"Command Center is not using live manual dashboard")
ok(admin:find("withAutomaticMonitorsHidden(function()return base.init",1,true),"Command Center init can still discover pinned monitors")
ok(room:find('require("clients.manual_dashboard_v2")',1,true),"remote wall client is not using live manual dashboard")
ok(room:find("if normal.init then normal.init",1,true)and room:find("withAutomaticMonitorsHidden",1,true),"remote wall init is not guarded")
ok(auth:find("peripheral.wrap=function",1,true)and auth:find("peripheral.call=function",1,true)and auth:find("peripheral.find=function",1,true),"hard authority routes are missing")

print("alpha88 live manual-screen hard-lock smoke: OK")
