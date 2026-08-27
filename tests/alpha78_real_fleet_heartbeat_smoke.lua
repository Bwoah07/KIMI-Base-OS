local realPrint=print

local function reset(name)package.loaded[name]=nil end
local function indexOf(events,kind)
 for i,e in ipairs(events)do if e.kind==kind then return i end end
end

-- Client: once Main Base is known, heartbeat must leave BEFORE module scanning.
do
 local events={};local now=10000
 os.epoch=function()return now end;os.getComputerID=function()return 7 end
 local network={
  findServer=function()events[#events+1]={kind="FIND"};return 42 end,
  send=function(id,cfg,kind,payload)events[#events+1]={kind=kind,id=id,payload=payload};return true end,
 }
 local loader={readAll=function()events[#events+1]={kind="SCAN"};return{}end}
 package.loaded["core.network"]=network;package.loaded["core.module_loader"]=loader
 package.loaded["core.fleet_identity"]={newSession=function()return"session"end,snapshot=function()return{version="5.0.0-alpha.78"}end}
 package.loaded["roles.client_v7"]={run=function(cfg)local id=network.findServer(cfg);loader.readAll({},{});return id end}
 local client=assert(loadfile("roles/client_v8.lua"))();client.run({profile="wall",network={protocol="kimi"}})
 local hb,scan=indexOf(events,"fleet.heartbeat"),indexOf(events,"SCAN")
 assert(hb and scan and hb<scan,"client heartbeat must be sent before hardware scan")
 assert(events[hb].id==42 and events[hb].payload.heartbeat==true,"client heartbeat target/payload wrong")
end

-- Pocket-style path: even with no hardware scan, state.get must trigger heartbeat.
do
 local events={};os.epoch=function()return 20000 end;os.getComputerID=function()return 8 end
 local network={findServer=function()return 42 end,send=function(id,cfg,kind,payload)events[#events+1]={kind=kind,id=id,payload=payload};return true end}
 local loader={readAll=function()return{}end}
 package.loaded["core.network"]=network;package.loaded["core.module_loader"]=loader
 package.loaded["core.fleet_identity"]={newSession=function()return"pocket-session"end,snapshot=function()return{version="5.0.0-alpha.78"}end}
 package.loaded["roles.client_v7"]={run=function(cfg)local id=network.findServer(cfg);network.send(id,cfg,"state.get",{});return true end}
 local client=assert(loadfile("roles/client_v8.lua"))();client.run({profile="pocket",network={protocol="kimi"}})
 assert(events[1]and events[1].kind=="fleet.heartbeat","Pocket state.get did not emit real heartbeat first")
 assert(events[2]and events[2].kind=="state.get","Pocket state.get was lost")
end

-- Remote node: heartbeat must also precede slow sensor/machine scans.
do
 local events={};os.epoch=function()return 30000 end;os.getComputerID=function()return 9 end
 local network={findServer=function()return 42 end,send=function(id,cfg,kind,payload)events[#events+1]={kind=kind,id=id,payload=payload};return true end}
 local loader={readAll=function()events[#events+1]={kind="SCAN"};return{}end}
 package.loaded["core.network"]=network;package.loaded["core.module_loader"]=loader
 package.loaded["core.fleet_identity"]={newSession=function()return"node-session"end,snapshot=function()return{version="5.0.0-alpha.78"}end}
 package.loaded["roles.node_v4"]={run=function(cfg)network.findServer(cfg);loader.readAll({},{});return true end}
 local node=assert(loadfile("roles/node_v5.lua"))();node.run({network={protocol="kimi"}})
 local hb,scan=indexOf(events,"fleet.heartbeat"),indexOf(events,"SCAN")
 assert(hb and scan and hb<scan,"node heartbeat must be sent before hardware scan")
end

-- Server: the dedicated packet feeds the existing fleet.hello/touchMachine path.
do
 local observed
 os.pullEvent=function()return"rednet_message",9,{kind="fleet.heartbeat",payload={name="QUARRY",heartbeat=true}},"kimi"end
 package.loaded["roles.server_v5"]={run=function(cfg)observed={os.pullEvent()};return true end}
 local server=assert(loadfile("roles/server_v6.lua"))();server.run({network={protocol="kimi"}})
 assert(observed and observed[1]=="rednet_message"and observed[2]==9,"server lost heartbeat event")
 assert(type(observed[3])=="table"and observed[3].kind=="fleet.hello","server did not route heartbeat through fleet presence path")
 assert(observed[3].payload.heartbeat==true,"heartbeat marker was lost")
end

local k=assert(io.open("kimi.lua","r")):read("*a")
assert(k:find('rolePath = "roles.server_v7"',1,true),"kernel is not using current server_v7")
assert(k:find('rolePath = "roles.client_v8"',1,true),"kernel is not using client_v8")
assert(k:find('rolePath = "roles.node_v5"',1,true),"kernel is not using node_v5")
local sv7=assert(io.open("roles/server_v7.lua","r")):read("*a")
assert(sv7:find('roles.server_v6',1,true),"alpha79 server throttle lost alpha78 heartbeat server lineage")

realPrint("alpha78 real fleet heartbeat smoke test OK")
