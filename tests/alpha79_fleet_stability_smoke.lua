package.path="./?.lua;./?/init.lua;"..package.path

local health=require("core.fleet_health")
-- Later releases may deliberately make fleet presence calmer, but must never
-- regress below alpha79's one-minute LIVE / five-minute OFFLINE grace.
assert(health.ONLINE_MS>=60000,"fleet LIVE grace regressed below alpha79")
assert(health.OFFLINE_MS>=300000,"fleet OFFLINE grace regressed below alpha79")
local now=1000000
assert(select(1,health.status(9,{lastSeen=now-59000},7,now))=="ONLINE","59s heartbeat gap must remain LIVE")
local at90=select(1,health.status(9,{lastSeen=now-90000},7,now))
assert(at90=="ONLINE"or at90=="STALE","90s heartbeat gap became OFFLINE")
local at301=select(1,health.status(9,{lastSeen=now-301000},7,now))
assert(at301=="STALE"or at301=="OFFLINE","301s heartbeat gap returned invalid presence state")

-- Prove server_v7 samples heavy modules on the slow lane while retaining their
-- cached values between scans.
local clock=0
os=os or{}
os.epoch=function()return clock end
local counts={}
local loader={}
loader.readAll=function(modules,previous)
    local out={}
    for k,v in pairs(previous or{})do out[k]=v end
    for id in pairs(modules or{})do
        counts[id]=(counts[id]or 0)+1
        out[id]={sample=counts[id]}
    end
    return out
end
package.loaded["core.module_loader"]=loader
package.loaded["roles.server_v6"]={run=function()
    local mods={doors={},environment={},system={},attachments={},power={},power_reserve={},ae2={},builder={}}
    local s={}
    s=loader.readAll(mods,s)
    assert(s.ae2 and s.ae2.sample==1,"initial heavy server telemetry missing")
    clock=500
    s=loader.readAll(mods,s)
    assert(s.ae2 and s.ae2.sample==1,"heavy telemetry cache was dropped between scans")
    clock=4999
    s=loader.readAll(mods,s)
    assert(s.builder and s.builder.sample==1,"Builder cache was dropped before slow interval")
    clock=5000
    s=loader.readAll(mods,s)
    assert(s.ae2.sample==2 and s.builder.sample==2,"heavy telemetry did not resample at 5 seconds")
    return true
end}
package.loaded["roles.server_v7"]=nil
require("roles.server_v7").run({})
assert(counts.doors==4 and counts.environment==4 and counts.system==4,"fast server telemetry was throttled")
assert(counts.ae2==2 and counts.power==2 and counts.attachments==2 and counts.builder==2,"heavy server telemetry is still running every UI tick")

local function read(path)local f=assert(io.open(path,"r"));local s=f:read("*a");f:close();return s end
local node=read("roles/node.lua")
assert(not node:find("hasUnhealthyState",1,true),"node still treats optional offline modules as network failure")
assert(node:find("rediscoverMs=30000",1,true),"node rediscovery safety interval missing")
local kimi=read("kimi.lua")
assert(kimi:find("roles.server_v7",1,true),"kernel is not using alpha79 server throttle")
assert(read("roles/server_v7.lua"):find("HEAVY_MS=5000",1,true),"server heavy telemetry cadence missing")
assert(read("roles/client_v8.lua"):find('"fleet.heartbeat"',1,true),"alpha78 real client heartbeat disappeared")
assert(read("roles/node_v5.lua"):find('"fleet.heartbeat"',1,true),"alpha78 real node heartbeat disappeared")
assert(read("roles/client_v4.lua"):find('"door.command.direct"',1,true),"alpha70 direct Pocket door path disappeared")

print("alpha79 fleet stability smoke test OK")
