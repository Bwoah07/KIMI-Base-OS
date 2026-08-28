package.path = "./?.lua;./?/init.lua;" .. package.path

local function fail(msg) error("alpha83: "..tostring(msg),0) end
local function ok(v,msg) if not v then fail(msg) end end
local function hasCandidate(list,target,side)
    for _,c in ipairs(list or {}) do if tostring(c.target)==tostring(target) and tostring(c.side)==tostring(side) then return true,c end end
    return false
end

-- Redstone Relay regression: CC:Tweaked relays use relative computer sides.
_G.fs = {}
os.epoch = os.epoch or function() return 123456 end
_G.peripheral = {
    getNames=function() return {"relay_0","integrator_0","legacy_0"} end,
    getType=function(name)
        if name=="relay_0" then return "redstone_relay" end
        if name=="integrator_0" then return "redstone_integrator" end
        return "legacy_redstone_box"
    end,
    getMethods=function() return {"setOutput","getOutput","getInput"} end,
    call=function(name,method,side,value)
        local relative={top=true,bottom=true,left=true,right=true,front=true,back=true}
        local cardinal={north=true,south=true,east=true,west=true,up=true,down=true}
        if name=="relay_0" and not relative[side] then error("relay rejected side "..tostring(side)) end
        if name=="integrator_0" and not (relative[side] or cardinal[side]) then error("integrator rejected side") end
        if name=="legacy_0" and not cardinal[side] then error("legacy rejected side "..tostring(side)) end
        if method=="getOutput" or method=="getInput" then return false end
        return true
    end,
}
_G.redstone = {}
package.loaded["core.doors_impl"] = nil
local doors=require("core.doors_impl")
local snapshot=doors.read()
ok(hasCandidate(snapshot.candidates,"relay_0","front"),"redstone relay must expose relative/front side")
ok(not hasCandidate(snapshot.candidates,"relay_0","north"),"redstone relay must not expose cardinal/north side")
ok(hasCandidate(snapshot.candidates,"integrator_0","top"),"redstone integrator must expose relative sides")
ok(hasCandidate(snapshot.candidates,"integrator_0","west"),"redstone integrator must keep cardinal compatibility")
ok(hasCandidate(snapshot.candidates,"legacy_0","north"),"unknown legacy actuator must preserve cardinal compatibility")

-- Monitor-map normalization is deterministic and rejects unknown views.
package.loaded["core.monitor_config"] = nil
local monitorConfig=require("core.monitor_config")
local map=monitorConfig.set(nil,"monitor_7","power")
ok(monitorConfig.get(map,"monitor_7")=="power","manual power assignment was not retained")
map=monitorConfig.set(map,"monitor_7","definitely_not_a_view")
ok(monitorConfig.get(map,"monitor_7")=="auto","unknown view should normalize to auto")
local views=monitorConfig.views();local foundDoors,foundBuilder=false,false
for _,v in ipairs(views)do if v=="doors"then foundDoors=true elseif v=="builder"then foundBuilder=true end end
ok(foundDoors and foundBuilder,"expected door and builder monitor choices")

-- Wall clients must no longer enter a door wizard merely because no door exists.
local function slurp(path)
    local f=assert(io.open(path,"r"));local s=f:read("*a");f:close();return s
end
local room=slurp("clients/room_v18.lua")
ok(not room:find("door_setup_request",1,true),"room_v18 still depends on automatic door setup flag")
ok(not room:find("clients.room_v15",1,true),"room_v18 still loads legacy automatic door wizard")
local wall=slurp("clients/wall.lua")
ok(wall:find("clients.room_v18",1,true),"wall profile is not routed through room_v18")
local doorCmd=slurp("door.lua")
ok(doorCmd:find("door_setup",1,true),"door setup command is not standalone")

print("alpha83 touchscreen setup smoke: OK")
