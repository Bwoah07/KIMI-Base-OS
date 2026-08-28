package.path="./?.lua;./?/init.lua;"..package.path

local truth=require("core.fleet_truth")
local now=1000000
local st,age,verified=truth.status(7,{lastSeen=1},7,now)
assert(st=="ONLINE"and verified==true,"Main Server lost authoritative ONLINE status")
st,age,verified=truth.status(10,{lastSeen=now-1000,verifiedAt=now-1000,version="5.0.0-alpha.75"},7,now)
assert(st=="ONLINE"and verified==true and truth.versionText({version="5.0.0-alpha.75"},true)=="LIVE 5.0.0-alpha.75","fresh identity proof is not LIVE")
st,age,verified=truth.status(10,{lastSeen=now-1000,version="5.0.0-alpha.73"},7,now)
assert(st=="VERIFY"and verified==false and truth.versionText({version="5.0.0-alpha.73"},false)=="LAST 5.0.0-alpha.73","historical proof policy unexpectedly changed")
st,age,verified=truth.status(11,{lastSeen=now-700000,version="5.0.0-alpha.73"},7,now)
assert((st=="STALE"or st=="GHOST")and verified==false,"historical sleeping/ghost policy returned invalid state")
assert(truth.shouldForget({lastSeen=now-90000000},now)==true,"day-old ghosts should be forgettable")

local realOs=os
local versionBody="5.0.0-alpha.75\n"
fs={exists=function(p)return p=="version.txt"end,isDir=function()return false end,open=function()return{readAll=function()return versionBody end,close=function()end}end}
os={getComputerID=function()return 10 end,getComputerLabel=function()return"Upper Door"end,epoch=function()return 123456 end,time=function()return 0 end}
package.loaded["core.fleet_identity"]=nil
local identity=require("core.fleet_identity")
local snap=identity.snapshot({name="KIMI-10",profile="wall"},"client","wall",identity.newSession("client"))
assert(snap.name=="Upper Door"and snap.version=="5.0.0-alpha.75"and snap.role=="client"and snap.sessionId:find("client:10:",1,true),"live identity snapshot does not prove label/version/session")
os=realOs

local function read(path)local f=assert(io.open(path,"r"));local s=f:read("*a");f:close();return s end
local kimi=read("kimi.lua")
assert(kimi:find("roles.server_v7",1,true)and kimi:find("roles.client_v8",1,true)and kimi:find("roles.node_v5",1,true),"kernel is not routing through current fleet wrappers")
local sv=read("roles/server_v4.lua");assert(sv:find('"fleet.identity"',1,true)and sv:find("kimiFleetProof",1,true)and sv:find('kind="fleet.hello"',1,true),"server fleet proof transport incomplete")
assert(read("roles/server_v5.lua"):find('roles.server_v4',1,true),"alpha77 server wrapper lost alpha75 proof lineage")
assert(read("roles/server_v6.lua"):find('roles.server_v5',1,true),"alpha78 server wrapper lost alpha77/75 proof lineage")
assert(read("roles/server_v7.lua"):find('roles.server_v6',1,true),"alpha79 server throttle lost alpha78/77/75 lineage")
assert(read("roles/client_v6.lua"):find('"fleet.identity"',1,true),"clients do not publish live identity proof")
assert(read("roles/client_v7.lua"):find('roles.client_v6',1,true),"alpha77 client wrapper lost alpha75 proof lineage")
assert(read("roles/client_v8.lua"):find('roles.client_v7',1,true),"alpha78 client wrapper lost alpha77/75 proof lineage")
assert(read("roles/node_v3.lua"):find('"fleet.identity"',1,true),"nodes do not publish live identity proof")
assert(read("roles/node_v4.lua"):find('roles.node_v3',1,true),"alpha77 node wrapper lost alpha75 proof lineage")
assert(read("roles/node_v5.lua"):find('roles.node_v4',1,true),"alpha78 node wrapper lost alpha77/75 proof lineage")
assert(read("clients/admin.lua"):find("clients.admin_v31",1,true),"admin is not loading current alpha83 fleet/UI wrapper")
assert(read("clients/admin_v31.lua"):find('require("clients.admin_v30")',1,true),"alpha83 manual-screen wrapper lost truthful v30 lineage")
local ui=read("clients/admin_v26.lua");assert(ui:find("truth.status",1,true)and ui:find("truth.versionText",1,true)and ui:find("PROVED NOW",1,true),"historical fleet truth overlay was removed from compatibility chain")
local current=read("clients/admin_v29.lua");assert(current:find("health.reachability",1,true)and current:find("CONFIRMED ID",1,true)and current:find('"OFFLINE"',1,true),"current operational fleet screen is not strict heartbeat/ACK driven")
assert(read("clients/admin_v30.lua"):find('require("clients.admin_v29")',1,true),"final truthful UI lost v29 lineage")
assert(read("roles/client_v4.lua"):find('"door.command.direct"',1,true),"alpha70 direct Pocket door path disappeared")

print("alpha75 fleet truth smoke test OK")
