local realPrint=print
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
local cfg={name="Main Base",localUI=false,network={protocol="kimi-test",hostname="main"}}
package.loaded["core.network"]={
 host=function()end,openAll=function()end,lookupAll=function()return{}end,
 send=function(target,c,kind,payload)
  sends[#sends+1]={target=target,kind=kind,payload=payload}
  return true
 end
}
package.loaded["core.config"]={load=function()return cfg end}
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
  if not e then error("__ALPHA63_STOP__",0) end
  return unpack(e)
 end
}

package.loaded["roles.server"]=nil
local server=assert(loadfile("roles/server.lua"))()
local ok,err=pcall(server.run,cfg)
assert(ok==false and tostring(err):find("__ALPHA63_STOP__",1,true),"real server loop did not terminate as expected: "..tostring(err))

local forwarded
for _,s in ipairs(sends)do
 if s.target==42 and s.kind=="module.command" then forwarded=s break end
end
assert(forwarded,"real Main Base server never sent a module.command to room computer 42")
assert(forwarded.payload.module=="doors","destination received wrong module: "..tostring(forwarded.payload.module))
assert(forwarded.payload.action=="open","destination lost OPEN action")
assert(tostring(forwarded.payload.args._source)=="42","router did not restore destination ownership _source")
assert(forwarded.payload.args.target=="redstone_integrator_0" and forwarded.payload.args.side=="east","router changed actuator identity")

-- Destination local door uses saved INVERTED config and must drive physical OFF
-- to become logically OPEN.
local physical=true
peripheral={
 call=function(name,method,side,value)
  assert(name=="redstone_integrator_0","wrong integrator")
  if method=="setOutput" then assert(side=="east","wrong side");physical=value;return end
  if method=="getOutput" then assert(side=="east","wrong side");return physical end
  error("unexpected peripheral method "..tostring(method))
 end,
 getMethods=function()return{"setOutput","getOutput"}end
}
sleep=function()end
package.loaded["core.doors_impl"]={handleCommand=function()error("configured door fell through to generic implementation")end}
package.loaded["modules.doors"]=nil
local doors=assert(loadfile("modules/doors.lua"))()
local saved={localDoors={{target="redstone_integrator_0",side="east",kind="digital_side",mode="invert",open=false,signal=true}}}
local result=doors.handleCommand(forwarded.payload.action,forwarded.payload.args,saved)
assert(result and result.open==true,"destination did not become logically OPEN")
assert(physical==false,"INVERTED OPEN did not drive physical redstone OFF")

os=realOs
realPrint("alpha63 REAL Pocket -> Main Base server -> room door smoke test OK")
