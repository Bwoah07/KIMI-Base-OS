package.path="./?.lua;./?/init.lua;"..package.path

local h=require("core.fleet_health")
local now=1000000

local st,age=h.status(7,{lastSeen=1,ageMs=999999},7,now)
assert(st=="ONLINE" and age==0,"Main Server must always be ONLINE")
st,age=h.status(8,{lastSeen=now-14000},7,now);assert(st=="ONLINE" and age==14000,"fresh remembered fleet member should remain historically ONLINE")
st,age=h.status(9,{lastSeen=now-59000},7,now);assert(st=="ONLINE" and age==59000,"brief telemetry stall should remain historically ONLINE")
st,age=h.status(10,{lastSeen=now-90000},7,now);assert((st=="ONLINE"or st=="STALE")and age==90000,"long heartbeat history became invalid")
st,age=h.status(11,{lastSeen=now-299000},7,now);assert(st=="ONLINE"or st=="STALE","five-minute history window regressed to invalid OFFLINE")
st,age=h.status(12,{lastSeen=now-301000},7,now);assert(st=="STALE"or st=="OFFLINE","missing fleet member returned invalid historical status")

st,age=h.reachability(8,{lastSeen=now-6000},7,now);assert(st=="ONLINE"and age==6000,"strict reachability lost fresh ONLINE state")
st,age=h.reachability(9,{lastSeen=now-10000},7,now);assert(st=="LATE"and age==10000,"strict reachability lost LATE state")
st,age=h.reachability(10,{lastSeen=now-20000},7,now);assert(st=="OFFLINE"and age==20000,"strict reachability still lies about dead machines")

local function read(path)local f=assert(io.open(path,"r"));local s=f:read("*a");f:close();return s end
-- Current UI chain is admin -> v32 (exclusive manual ownership) -> v30 -> v29.
local admin=read("clients/admin.lua");assert(admin:find("clients.admin_v32",1,true),"admin profile lost current UI lineage")
local v32=read("clients/admin_v32.lua");assert(v32:find('require("clients.admin_v30")',1,true)and v32:find("core.monitor_authority",1,true),"v32 stopped inheriting truthful fleet UI or monitor authority")
local overlay=read("clients/admin_v25.lua");assert(overlay:find("health.status",1,true),"historical fleet overlay lineage lost shared health policy");assert(overlay:find("serverId",1,true),"fleet overlay lost Main Server identity handling")
local current=read("clients/admin_v29.lua");assert(current:find("health.reachability",1,true)and current:find('"ONLINE"',1,true)and current:find('"LATE"',1,true)and current:find('"OFFLINE"',1,true),"current fleet screen is not strict heartbeat-driven")
local final=read("clients/admin_v30.lua");assert(final:find('require("clients.admin_v29")',1,true),"v30 stopped inheriting truthful fleet overlay")

print("alpha74 fleet sanity smoke test OK")
