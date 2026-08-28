package.path="./?.lua;./?/init.lua;"..package.path

local health=require("core.fleet_health")
assert(health.HEARTBEAT_MS==2000,"dedicated heartbeat cadence contract changed")
assert(health.REACHABLE_MS==6500,"ONLINE must mean a heartbeat within 6.5 seconds")
assert(health.LATE_MS==15000,"LATE window must stop at 15 seconds")

local now=100000
assert(select(1,health.reachability(9,{lastSeen=now-6000},7,now))=="ONLINE","6s heartbeat age must be ONLINE")
assert(select(1,health.reachability(9,{lastSeen=now-7000},7,now))=="LATE","7s heartbeat age must be LATE, never green")
assert(select(1,health.reachability(9,{lastSeen=now-14900},7,now))=="LATE","14.9s heartbeat age must remain LATE")
assert(select(1,health.reachability(9,{lastSeen=now-15100},7,now))=="OFFLINE","15.1s heartbeat age must be OFFLINE")
assert(select(1,health.reachability(7,{lastSeen=0},7,now))=="ONLINE","Main Base must remain locally ONLINE")

-- Alpha80's long remembered/sleeping history may remain for compatibility, but
-- the operational UI/server must use strict reachability instead of status().
assert(health.ONLINE_MS==120000 and health.OFFLINE_MS==1800000,"alpha80 historical retention contract unexpectedly changed")

local function read(path)local f=assert(io.open(path,"r"));local s=f:read("*a");f:close();return s end
local server=read("roles/server.lua")
assert(server:find('require("core.fleet_health")',1,true),"server is not using shared fleet health")
assert(server:find("fleetHealth.reachability",1,true),"server still uses independent hard-coded liveness")
assert(server:find("source.lastHeartbeat=now",1,true),"heartbeat does not refresh telemetry source reachability")
assert(server:find("lastHeartbeat=seen",1,true),"telemetry source does not initialize heartbeat truth")
assert(server:find("source.online==true",1,true),"canonical telemetry still accepts non-live sources")

local admin=read("clients/admin.lua")
assert(admin:find("admin_v28",1,true),"current admin profile is not alpha81 truth overlay")
local v28=read("clients/admin_v28.lua")
assert(v28:find("health.reachability",1,true),"fleet display is not using strict heartbeat truth")
assert(v28:find("ONLINE ",1,true)and v28:find("LATE ",1,true)and v28:find("OFFLINE ",1,true),"fleet summary lost explicit ONLINE/LATE/OFFLINE states")
assert(not v28:find("HIDDEN ",1,true),"operational fleet still hides remembered computers")
assert(v28:find("NO LIVE MATRIX TELEMETRY",1,true),"power screen still confuses missing telemetry with missing hardware")
assert(v28:find("WAITING FOR LIVE MAIN",1,true),"reserve screen does not explain missing Main telemetry")
assert(v28:find("NO LIVE FLUX TELEMETRY",1,true),"Flux screen does not distinguish offline telemetry")

local client8=read("roles/client_v8.lua")
local node5=read("roles/node_v5.lua")
assert(client8:find("HEARTBEAT_MS=2000",1,true)and node5:find("HEARTBEAT_MS=2000",1,true),"real pre-scan heartbeat regressed")
local client4=read("roles/client_v4.lua")
assert(client4:find('"door.command.direct"',1,true),"alpha70 direct Pocket door path disappeared")

print("alpha81 truthful fleet/power smoke test OK")
