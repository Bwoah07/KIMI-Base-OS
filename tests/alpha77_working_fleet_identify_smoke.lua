package.path="./?.lua;./?/init.lua;"..package.path

local realPrint=print
colors={black=1,white=2,lightGray=3,lime=4,orange=5,red=6,gray=7,cyan=8,lightBlue=9,yellow=10}
local now=1000000
local function mon(w,h)
 local cells={};local cx,cy=1,1
 local m={}
 function m.setTextScale()end
 function m.getSize()return w,h end
 function m.setBackgroundColor()end
 function m.setTextColor()end
 function m.clear()cells={}end
 function m.setCursorPos(x,y)cx,cy=x,y end
 function m.write(s)cells[cy]=cells[cy]or{};cells[cy][cx]=tostring(s)end
 function m.output()local out={};for y=1,h do local row=cells[y]or{};local parts={};for _,s in pairs(row)do parts[#parts+1]=s end;out[#out+1]=table.concat(parts," ")end;return table.concat(out,"\n")end
 return m
end
local main,power,fleet=mon(80,30),mon(50,20),mon(30,30)
local devices={main=main,power=power,fleet=fleet}
peripheral={getNames=function()return{"main","power","fleet"}end,getType=function(n)return devices[n]and"monitor"or nil end,hasType=function(n,t)return devices[n]~=nil and t=="monitor"end,wrap=function(n)return devices[n]end}
os={epoch=function()return now end,time=function()return 9.5 end,getComputerLabel=function()return"Main Server"end,getComputerID=function()return 7 end}

package.loaded["clients.admin_v26"]={init=function()return true end,render=function()return true end,handleEvent=function()return false end}
package.loaded["clients.admin_v27"]=nil
local admin=require("clients.admin_v27")
admin.init({name="Main Server"})
local env={serverId=7,version="5.0.0-alpha.77",state={fleet={
 [7]={name="Main Server",role="server",version="5.0.0-alpha.77",lastSeen=1},
 [9]={name="Outdoor Sensors",role="node",version="5.0.0-alpha.77",lastSeen=now-8000},
 [10]={name="Upper Door",role="client",version="5.0.0-alpha.77",lastSeen=now-50000},
 [11]={name="KIMI-11",role="client",version="5.0.0-alpha.70",lastSeen=now-700000}
}}}
assert(admin.render(env,{})~=false,"admin render failed")
local out=fleet.output()
assert(out:find("FLEET / IDENTIFY",1,true),"fleet screen missing")
assert(out:find("ID 9 OUTDOOR SENSORS",1,true)and out:find("LIVE",1,true),"fresh heartbeat is not shown LIVE")
assert(out:find("ID 10 UPPER DOOR",1,true)and out:find("STALE",1,true),"stale-but-reachable machine missing")
assert(not out:find("ID 11",1,true),"ancient ghost is still cluttering the operational list")
assert(out:find("HIDDEN 1",1,true),"hidden-history count missing")
assert(not out:find("VERIFY",1,true)and not out:find("GHOST",1,true)and not out:find("LAST ",1,true),"fleet archaeology labels leaked back into the live screen")

local called=nil
local function action(module,verb,args)called={module=module,verb=verb,id=args and args.id};return{ok=true}end
assert(admin.handleEvent({"monitor_touch","fleet",5,12},env,action)==true,"fleet touch not handled")
assert(called and called.module=="server"and called.verb=="identify"and called.id==9,"touch did not identify the live target")
_G.kimiIdentifyAck={ ["9"]={at=now+1,name="Outdoor Sensors"} }
now=now+500
admin.render(env,{})
out=fleet.output()
assert(out:find("CONFIRMED ID 9 FLASHING",1,true),"real identify ACK is not surfaced")
_G.kimiIdentifyAck=nil

local function read(path)local f=assert(io.open(path,"r"));local s=f:read("*a");f:close();return s end
local kimi=read("kimi.lua")
assert(kimi:find("roles.server_v6",1,true)and kimi:find("roles.client_v8",1,true)and kimi:find("roles.node_v5",1,true),"kernel is not routed through current fleet wrappers")
assert(read("roles/server_v6.lua"):find('roles.server_v5',1,true),"alpha78 server wrapper lost alpha77 identify lineage")
assert(read("roles/client_v8.lua"):find('roles.client_v7',1,true),"alpha78 client wrapper lost alpha77 identify lineage")
assert(read("roles/node_v5.lua"):find('roles.node_v4',1,true),"alpha78 node wrapper lost alpha77 identify lineage")
assert(read("roles/server_v5.lua"):find('"fleet.identify.ack"',1,true)and read("roles/server_v5.lua"):find("PURGE_MS=600000",1,true),"server ACK/purge transport incomplete")
assert(read("roles/client_v7.lua"):find('"fleet.identify.ack"',1,true),"clients do not ACK identify")
assert(read("roles/node_v4.lua"):find('"fleet.identify.ack"',1,true),"nodes do not ACK identify")
assert(read("clients/admin.lua"):find("clients.admin_v27",1,true),"admin is not loading working fleet screen")
assert(read("clients/admin_v27.lua"):find("CONFIRMED ID",1,true)and read("clients/admin_v27.lua"):find("NOT REACHABLE",1,true),"identify feedback contract missing")
assert(read("roles/client_v4.lua"):find('"door.command.direct"',1,true),"alpha70 direct Pocket door path disappeared")

realPrint("alpha77 working fleet identify smoke test OK")
