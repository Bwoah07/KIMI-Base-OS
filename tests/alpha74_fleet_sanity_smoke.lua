package.path="./?.lua;./?/init.lua;"..package.path

local h=require("core.fleet_health")
local now=1000000

local st,age=h.status(7,{lastSeen=1,ageMs=999999},7,now)
assert(st=="ONLINE" and age==0,"Main Server must always be ONLINE")

st,age=h.status(8,{lastSeen=now-14000},7,now)
assert(st=="ONLINE" and age==14000,"fresh remembered fleet member should remain historically ONLINE")

st,age=h.status(9,{lastSeen=now-59000},7,now)
assert(st=="ONLINE" and age==59000,"brief telemetry stall should remain historically ONLINE")

-- Historical/presence memory remains deliberately calm for compatibility.
st,age=h.status(10,{lastSeen=now-90000},7,now)
assert((st=="ONLINE"or st=="STALE")and age==90000,"long heartbeat history became invalid")

st,age=h.status(11,{lastSeen=now-299000},7,now)
assert(st=="ONLINE"or st=="STALE","five-minute history window regressed to invalid OFFLINE")

st,age=h.status(12,{lastSeen=now-301000},7,now)
assert(st=="STALE"or st=="OFFLINE","missing fleet member returned invalid historical status")

-- Operational truth is now a separate, strict API.
st,age=h.reachability(8,{lastSeen=now-6000},7,now)
assert(st=="ONLINE"and age==6000,"strict reachability lost fresh ONLINE state")
st,age=h.reachability(9,{lastSeen=now-10000},7,now)
assert(st=="LATE"and age==10000,"strict reachability lost LATE state")
st,age=h.reachability(10,{lastSeen=now-20000},7,now)
assert(st=="OFFLINE"and age==20000,"strict reachability still lies about dead machines")

-- Alpha83 adds a manual-monitor overlay, but the truthful fleet UI must remain
-- in the inheritance chain: admin -> v31 -> v30 -> v29.
local f=assert(io.open("clients/admin.lua","r"));local admin=f:read("*a");f:close()
assert(admin:find("clients.admin_v31",1,true),"admin profile lost current alpha83 UI lineage")
local f31=assert(io.open("clients/admin_v31.lua","r"));local v31=f31:read("*a");f31:close()
assert(v31:find('require("clients.admin_v30")',1,true),"v31 stopped inheriting truthful fleet UI")
local f2=assert(io.open("clients/admin_v25.lua","r"));local overlay=f2:read("*a");f2:close()
assert(overlay:find("health.status",1,true),"historical fleet overlay lineage lost shared health policy")
assert(overlay:find("serverId",1,true),"fleet overlay lost Main Server identity handling")
local f3=assert(io.open("clients/admin_v29.lua","r"));local current=f3:read("*a");f3:close()
assert(current:find("health.reachability",1,true)and current:find('"ONLINE"',1,true)and current:find('"LATE"',1,true)and current:find('"OFFLINE"',1,true),"current fleet screen is not strict heartbeat-driven")
local f4=assert(io.open("clients/admin_v30.lua","r"));local final=f4:read("*a");f4:close()
assert(final:find('require("clients.admin_v29")',1,true),"v30 stopped inheriting truthful fleet overlay")

print("alpha74 fleet sanity smoke test OK")
