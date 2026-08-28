package.path="./?.lua;./?/init.lua;"..package.path

local function ok(v,msg)if not v then error("alpha86: "..tostring(msg),0)end end
local function read(path)local f=assert(io.open(path,"r"));local s=f:read("*a");f:close();return s end

-- Functional ownership test: a pinned monitor must be completely hidden from
-- adaptive code while unpinned monitors/peripherals remain visible.
package.loaded["core.monitor_config"]={
    load=function()return{assignments={monitor_0="doors",monitor_1="auto"}}end,
    normalizeView=function(v)return tostring(v or"auto")end,
}
local original=function()return{"monitor_0","monitor_1","geoScanner_0"}end
_G.peripheral={getNames=original}
package.loaded["core.monitor_authority"]=nil
local authority=require("core.monitor_authority")

local seen
local result=authority.withAutomaticMonitorsHidden(function()
    seen=peripheral.getNames()
    return"painted"
end)
ok(result=="painted","guard lost wrapped return value")
local foundPinned,foundAuto,foundGeo=false,false,false
for _,name in ipairs(seen or{})do
    if name=="monitor_0"then foundPinned=true elseif name=="monitor_1"then foundAuto=true elseif name=="geoScanner_0"then foundGeo=true end
end
ok(not foundPinned,"pinned DOORS monitor was still visible to adaptive renderer")
ok(foundAuto,"AUTO monitor was incorrectly hidden from adaptive renderer")
ok(foundGeo,"non-monitor peripheral was incorrectly hidden")
ok(peripheral.getNames==original,"peripheral.getNames was not restored after successful render")

local survived=pcall(function()
    authority.withAutomaticMonitorsHidden(function()error("legacy renderer exploded")end)
end)
ok(not survived,"guard swallowed legacy renderer error")
ok(peripheral.getNames==original,"peripheral.getNames was not restored after renderer error")

-- Lineage contract: current server and wall profiles must use the exclusive
-- authority wrappers rather than the old repaint-after-adaptive overlay.
local admin=read("clients/admin.lua")
local admin32=read("clients/admin_v32.lua")
local wall=read("clients/wall.lua")
local room19=read("clients/room_v19.lua")
ok(admin:find("clients.admin_v32",1,true),"Command Center is not routed through admin_v32")
ok(admin32:find("core.monitor_authority",1,true),"admin_v32 does not use monitor authority")
ok(admin32:find("withAutomaticMonitorsHidden",1,true),"admin_v32 does not hide pinned monitors from adaptive rendering")
ok(wall:find("clients.room_v19",1,true),"wall profile is not routed through room_v19")
ok(room19:find("withAutomaticMonitorsHidden",1,true),"room_v19 does not hide pinned monitors from automatic rendering")

local manifest=read("manifest.json")
local releaseAlpha=tonumber(manifest:match('"version"%s*:%s*"5%.0%.0%-alpha%.(%d+)"'))
ok(releaseAlpha and releaseAlpha>=86,"current release regressed below Alpha86")
ok(manifest:find('"core/monitor_authority.lua"',1,true),"monitor authority is missing from managed release")
ok(manifest:find('"clients/admin_v32.lua"',1,true)and manifest:find('"clients/room_v19.lua"',1,true),"new runtime lineage missing from manifest")

print("alpha86 exclusive manual screen authority smoke: OK")
