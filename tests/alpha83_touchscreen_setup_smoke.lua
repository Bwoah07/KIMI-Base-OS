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
_G.redstone = {getOutput=function() return false end,getInput=function() return false end,setOutput=function() return true end}
package.loaded["core.doors_impl"] = nil
local doors=require("core.doors_impl")
local snapshot=doors.read()
ok(hasCandidate(snapshot.candidates,"relay_0","front"),"redstone relay must expose relative/front side")
ok(not hasCandidate(snapshot.candidates,"relay_0","north"),"redstone relay must not expose cardinal/north side")
ok(hasCandidate(snapshot.candidates,"integrator_0","top"),"redstone integrator must expose relative sides")
ok(hasCandidate(snapshot.candidates,"integrator_0","west"),"redstone integrator must keep cardinal compatibility")
ok(hasCandidate(snapshot.candidates,"legacy_0","north"),"unknown legacy actuator must preserve cardinal compatibility")

-- Real save/load path: screen assignments and renamed doors must survive a
-- persistence round-trip rather than merely changing an in-memory UI value.
local files,dirs={}, {[".kimi"]=true}
_G.fs={
    exists=function(path) return dirs[path]==true or files[path]~=nil end,
    isDir=function(path) return dirs[path]==true end,
    makeDir=function(path) dirs[path]=true end,
    delete=function(path) files[path]=nil;dirs[path]=nil end,
    move=function(from,to) files[to]=files[from];files[from]=nil end,
    open=function(path,mode)
        if mode=="r" then
            local body=files[path];if body==nil then return nil end
            return {readAll=function() return body end,close=function() end}
        end
        local body=""
        return {
            write=function(v) body=body..tostring(v or "") end,
            writeLine=function(v) body=body..tostring(v or "").."\n" end,
            close=function() files[path]=body end,
        }
    end,
}
local serialized,n= {},0
_G.textutils={
    serialize=function(v) n=n+1;local token="SERIALIZED:"..n;serialized[token]=v;return token end,
    unserialize=function(raw) return serialized[raw] end,
}
package.loaded["core.doors_impl"] = nil
doors=require("core.doors_impl")
doors.handleCommand("register_local",{target="relay_0",side="front",name="OLD NAME"})
doors.handleCommand("configure_local",{target="relay_0",side="front",name="MAIN AIRLOCK",mode="invert",pulseSeconds=.5})
snapshot=doors.read()
local renamed
for _,d in ipairs(snapshot.localDoors or {}) do if d.target=="relay_0" and d.side=="front" then renamed=d end end
ok(renamed and renamed.name=="MAIN AIRLOCK","configured door rename did not persist")
ok(renamed.mode=="invert","door behavior was lost while renaming")

package.loaded["core.monitor_config"] = nil
local monitorConfig=require("core.monitor_config")
local map=monitorConfig.set(nil,"monitor_7","power")
monitorConfig.save(map)
map=monitorConfig.load()
ok(monitorConfig.get(map,"monitor_7")=="power","manual monitor assignment did not survive save/load")
map=monitorConfig.set(map,"monitor_7","definitely_not_a_view")
ok(monitorConfig.get(map,"monitor_7")=="auto","unknown view should normalize to auto")
local views=monitorConfig.views();local foundDoors,foundBuilder=false,false
for _,v in ipairs(views)do if v=="doors"then foundDoors=true elseif v=="builder"then foundBuilder=true end end
ok(foundDoors and foundBuilder,"expected door and builder monitor choices")

local function slurp(path)
    local f=assert(io.open(path,"r"));local s=f:read("*a");f:close();return s
end

-- Wall clients must no longer enter a door wizard merely because no door exists.
local room=slurp("clients/room_v18.lua")
ok(not room:find("door_setup_request",1,true),"room_v18 still depends on automatic door setup flag")
ok(not room:find("clients.room_v15",1,true),"room_v18 still loads legacy automatic door wizard")
ok(room:find("clients.manual_dashboard",1,true),"wall clients lost manual-screen overlay")
local wall=slurp("clients/wall.lua")
ok(wall:find("clients.room_v18",1,true),"wall profile is not routed through room_v18")

-- Setup must expose first-class naming and exact-monitor assignment, and the
-- standalone door wizard must pass edited names through configure_local.
local setup=slurp("setup.lua")
ok(setup:find("os.setComputerLabel",1,true) and setup:find("monitorConfig.set",1,true),"setup is missing computer naming or monitor assignment")
local installer=slurp("installer.lua")
local oldInstallerFlow=installer:find("Computer name [",1,true) and installer:find('shell.run("setup","monitors")',1,true)
local touchInstallerFlow=installer:find("Computer naming + monitor assignment will continue on the touchscreen",1,true) and installer:find('shell.run("setup")',1,true)
ok(oldInstallerFlow or touchInstallerFlow,"fresh installer is not wired into naming + monitor setup")
local doorCmd=slurp("door.lua")
ok(doorCmd:find("door_setup",1,true),"door setup command is not standalone")
local doorSetup=slurp("door_setup.lua")
ok(doorSetup:find("name=name,mode=mode",1,true),"touchscreen door update does not persist renamed name")
ok(doorSetup:find("name=name,mode=m",1,true),"terminal door update does not persist renamed name")
local admin=slurp("clients/admin.lua")
local admin31=slurp("clients/admin_v31.lua")
ok(admin:find("clients.admin_v31",1,true) and admin31:find("clients.manual_dashboard",1,true),"Command Center is not routed through manual-screen overlay")

print("alpha83 touchscreen setup smoke: OK")
