package.path="./?.lua;./?/init.lua;"..package.path

local h=require("core.fleet_health")
local now=1000000

local st,age=h.status(7,{lastSeen=1,ageMs=999999},7,now)
assert(st=="ONLINE" and age==0,"Main Server must always be ONLINE")

st,age=h.status(8,{lastSeen=now-14000},7,now)
assert(st=="ONLINE" and age==14000,"fresh fleet member should be ONLINE")

st,age=h.status(9,{lastSeen=now-59000},7,now)
assert(st=="ONLINE" and age==59000,"brief telemetry stall should remain ONLINE")

-- Later releases may increase the LIVE grace, but a 90-second gap must never
-- regress to OFFLINE.
st,age=h.status(10,{lastSeen=now-90000},7,now)
assert((st=="ONLINE"or st=="STALE")and age==90000,"long heartbeat loss became OFFLINE")

st,age=h.status(11,{lastSeen=now-299000},7,now)
assert(st=="ONLINE"or st=="STALE","five-minute grace window regressed to OFFLINE")

-- Alpha74 originally allowed OFFLINE after five minutes. Newer releases may
-- deliberately retain sleeping/chunk-unloaded infrastructure longer.
st,age=h.status(12,{lastSeen=now-301000},7,now)
assert(st=="STALE"or st=="OFFLINE","missing fleet member returned invalid status")

local f=assert(io.open("clients/admin.lua","r"));local admin=f:read("*a");f:close()
assert(admin:find("clients.admin_v27",1,true),"admin profile lost current fleet UI lineage")
local f2=assert(io.open("clients/admin_v25.lua","r"));local overlay=f2:read("*a");f2:close()
assert(overlay:find("health.status",1,true),"fleet overlay is not using shared health policy")
assert(overlay:find("serverId",1,true),"fleet overlay lost Main Server identity handling")
local f3=assert(io.open("clients/admin_v27.lua","r"));local current=f3:read("*a");f3:close()
assert(current:find("health.status",1,true)and current:find('"LIVE"',1,true)and current:find('"STALE"',1,true),"current fleet screen is not heartbeat-driven")

print("alpha74 fleet sanity smoke test OK")
