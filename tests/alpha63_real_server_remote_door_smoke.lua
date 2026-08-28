local realPrint=print
local unpack=table.unpack or unpack
colors={white=1,orange=2,lightBlue=8,lime=32,gray=128,lightGray=256,cyan=512,blue=2048,red=16384,black=32768}
keys={left=203,right=205,one=2,two=3,three=4,four=5,five=6,six=7,seven=8,eight=9,nine=10}

-- Pocket must send owner as `source`, NOT `_source`, so Main Base executes
-- modules.remote_doors instead of short-circuiting through generic forwarding.
local W,H=26,20;local rows,x,y={},1,1
term={getSize=function()return W,H end,setCursorPos=function(a,b)x,y=a,b end,setTextColor=function()end,setBackgroundColor=function()end,clear=function()rows={};x,y=1,1 end}
term.write=function(v)v=tostring(v or"");local row=rows[y]or string.rep(" ",W);v=v:sub(1,math.max(0,W-x+1));rows[y]=row:sub(1,x-1)..v..row:sub(x+#v);x=x+#v end
local realOs=os
os={getComputerLabel=function()return"Pocket"end,getComputerID=function()return 77 end,time=function()return 12 end,epoch=function()return 1000 end}
package.loaded["clients.pocket_v5"]=nil;package.loaded["clients.pocket"]=nil
local pocket=assert(loadfile("clients/pocket.lua"))();pocket.init({})
local env={version="5.0.0-alpha.63",state={doors={doors={{id="local:42|redstone_integrator_0|east",key="42|redstone_integrator_0|east",name="ROOM PANEL",_source="42",source="42",target="redstone_integrator_0",side="east",open=false,online=true}}},power={},attachments={sensors={}},fleet={}}}
pocket.render(env,{connected=true})
local requested
local function pocketAction(module,action,args)requested={module=module,action=action,args=args};return true,{queued=true}end
assert(pocket.handleEvent({"mouse_click",1,5,12},env,pocketAction)==true,"Pocket did not consume door tap")
assert(requested and requested.module=="remote_doors" and requested.action=="open","Pocket did not request remote OPEN")
assert(requested.args._source==nil,"Pocket still sends reserved _source and bypasses remote_doors")
assert(tostring(requested.args.source)=="42","Pocket lost room owner source")
assert(requested.args.target=="redstone_integrator_0" and requested.args.side=="east","Pocket lost actuator routing")

-- Run the REAL roles/server.lua event loop. Only infrastructure dependencies are
-- mocked. The server module itself is not replaced.
local sends={}
local mainCfg={name="Main Base",localUI=false,network={protocol="kimi-test",hostname="main"}}
package.loaded["core.network"]={
 host=function()end,openAll=function()end,lookupAll=function()return{}end,
 send=function(target,c,kind,payload)
  sends[#sends+1]={target=target,kind=kind,payload=payload}
  return true
 end
}
package.loaded["core.config"]={load=function()return mainCfg end}
package.loaded["core.update_service"]={
 localVersion=function()return"5.0.0-alpha.63"end,
 autoEnabled=function()return false end,
 interval=function()return 999999 end,
 hasPendingProbation=function()return false end,
 markHealthy=function()return true end
}
package.loaded["core.door_registry"]={
 load=function()return{}end,save=function()end,candidates=function()return{}end,
 snapshot=function()return{doors={},candidates={}}end,
 add=function()return nil,"unused"end,remove=function()return nil,"unused"end
}
package.loaded["core.fleet_registry"]={load=function()return{}end,save=function()end}

-- Load the real remote router against the mocked network/config.
package.loaded["modules.remote_doors"]=nil
local remoteDoors=assert(loadfile("modules/remote_doors.lua"))()
package.loaded["core.module_loader"]={
 discover=function()return{remote_doors=remoteDoors}end,
 readAll=function(_,old)return old or{}end
}

local events={
 {"rednet_message",77,{kind="command",payload={module=requested.module,action=requested.action,args=requested.args}},"kimi-test"},
}
local eventIndex=0
os={
 getComputerID=function()return 1 end,
 epoch=function()return 2000 end,
 startTimer=function()return 999 end,
 pullEvent=function()
  eventIndex=eventIndex+1
  local e=events[eventIndex]
  if not e then error("__ALPHA63_SERVER_STOP__",0) end
  return unpack(e)
 end
}

package.loaded["roles.server"]=nil
local server=assert(loadfile("roles/server.lua"))()
local ok,err=pcall(server.run,mainCfg)
assert(ok==false and tostring(err):find("__ALPHA63_SERVER_STOP__",1,true),"real server loop did not terminate as expected: "..tostring(err))

local forwarded
for _,s in ipairs(sends)do
 if s.target==42 and s.kind=="module.command" then forwarded=s break end
end
assert(forwarded,"real Main Base server never sent a module.command to room computer 42")
assert(forwarded.payload.module=="doors","destination received wrong module: "..tostring(forwarded.payload.module))
assert(forwarded.payload.action=="open","destination lost OPEN action")
assert(tostring(forwarded.payload.args._source)=="42","router did not restore destination ownership _source")
assert(forwarded.payload.args.target=="redstone_integrator_0" and forwarded.payload.args.side=="east","router changed actuator identity")

-- Run the REAL roles/client.lua event loop for room computer 42. This is the
-- final runtime hop that the old tests skipped. It must consume the server's
-- module.command and physically drive the saved INVERTED integrator output OFF.
local physical=true
peripheral={
 getMethods=function(name)
  assert(name=="redstone_integrator_0","wrong method target")
  return{"setOutput","getOutput"}
 end,
 call=function(name,method,side,value)
  assert(name=="redstone_integrator_0","wrong integrator")
  if method=="getOutput" then assert(side=="east","wrong get side");return physical end
  if method=="setOutput" then assert(side=="east","wrong set side");physical=value;return true end
  error("unexpected peripheral method "..tostring(method))
 end,
 getNames=function()return{}end,
 getType=function()return nil end,
 hasType=function()return false end,
 wrap=function()return nil end
}
sleep=function()end

local localState={doors={localDoors={{id="local:redstone_integrator_0|east",key="redstone_integrator_0|east",name="ROOM PANEL",target="redstone_integrator_0",side="east",kind="digital_side",mode="invert",open=false,signal=true,online=true}}}}
local clientSends={}
package.loaded["core.network"]={
 openAll=function()end,advertise=function()end,findServer=function()return 1 end,
 send=function(target,c,kind,payload)clientSends[#clientSends+1]={target=target,kind=kind,payload=payload};return true end
}
package.loaded["core.module_loader"]={
 discover=function()return{}end,
 readAll=function(_,old)return localState end
}
package.loaded["core.update_service"]={
 localVersion=function()return"5.0.0-alpha.63"end,
 hasPendingProbation=function()return false end,
 fleetManaged=function()return false end,
 markHealthy=function()return true end
}
package.loaded["clients.pocket"]={init=function()end,render=function()return true end,onState=function()end}

local timerId=100
local roomEvents={}
local roomEventIndex=0
os={
 getComputerID=function()return 42 end,
 getComputerLabel=function()return"Room Panel"end,
 epoch=function()return 3000 end,
 startTimer=function()timerId=timerId+1;return timerId end,
 pullEvent=function()
  roomEventIndex=roomEventIndex+1
  if roomEventIndex==1 then return"timer",101 end
  if roomEventIndex==2 then return"rednet_message",1,{kind="module.command",payload=forwarded.payload},"kimi-test" end
  error("__ALPHA63_CLIENT_STOP__",0)
 end
}

package.loaded["roles.client"]=nil
local client=assert(loadfile("roles/client.lua"))()
local roomCfg={name="Room Panel",profile="pocket",network={protocol="kimi-test",hostname="main"}}
local clientOk,clientErr=pcall(client.run,roomCfg)
assert(clientOk==false and tostring(clientErr):find("__ALPHA63_CLIENT_STOP__",1,true),"real room client loop did not terminate as expected: "..tostring(clientErr))
assert(physical==false,"REAL room client did not drive INVERTED OPEN to physical redstone OFF")

local sawResult=false
for _,s in ipairs(clientSends)do
 if s.target==1 and s.kind=="module.command.result" then sawResult=true;assert(s.payload.ok==true,"room client reported command failure")end
end
assert(sawResult,"room client never reported module.command.result")

os=realOs
realPrint("alpha63 REAL Pocket -> Main Base server -> room client -> redstone smoke test OK")
