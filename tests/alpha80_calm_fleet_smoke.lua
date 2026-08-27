package.path="./?.lua;./?/init.lua;"..package.path

local health=require("core.fleet_health")
assert(health.ONLINE_MS==120000,"alpha80 LIVE grace must be 2 minutes")
assert(health.OFFLINE_MS==1800000,"alpha80 sleeping grace must be 30 minutes")
local now=2000000
assert(select(1,health.status(9,{lastSeen=now-119000},7,now))=="ONLINE","119s heartbeat gap must remain LIVE")
assert(select(1,health.status(9,{lastSeen=now-121000},7,now))=="STALE","121s heartbeat gap must become STALE, not OFFLINE")
assert(select(1,health.status(9,{lastSeen=now-600000},7,now))=="STALE","10 minute chunk sleep must remain remembered/stale")
assert(select(1,health.status(9,{lastSeen=now-1799000},7,now))=="STALE","just under 30 minutes must remain stale")
assert(select(1,health.status(9,{lastSeen=now-1801000},7,now))=="OFFLINE","over 30 minutes may finally be offline")

local function read(path)local f=assert(io.open(path,"r"));local s=f:read("*a");f:close();return s end
local server5=read("roles/server_v5.lua")
assert(server5:find("PURGE_MS=86400000",1,true),"sleeping fleet members are still purged too aggressively")
local client8=read("roles/client_v8.lua")
assert(client8:find("HEARTBEAT_MS=2000",1,true),"real client heartbeat cadence regressed")
local node5=read("roles/node_v5.lua")
assert(node5:find("HEARTBEAT_MS=2000",1,true),"real node heartbeat cadence regressed")
local client4=read("roles/client_v4.lua")
assert(client4:find('"door.command.direct"',1,true),"alpha70 direct Pocket door path disappeared")

print("alpha80 calm fleet smoke test OK")
