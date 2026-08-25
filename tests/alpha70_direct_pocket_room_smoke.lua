local realPrint=print
local realOs=os

colors={white=1,orange=2,lightBlue=8,lime=32,gray=128,lightGray=256,cyan=512,blue=2048,red=16384,black=32768}
keys={left=203,right=205,one=2,two=3,three=4,four=5,five=6,six=7,seven=8,eight=9,nine=10}
local W,H=26,20;local rows,x,y={},1,1
term={getSize=function()return W,H end,setCursorPos=function(a,b)x,y=a,b end,setTextColor=function()end,setBackgroundColor=function()end,clear=function()rows={};x,y=1,1 end}
term.write=function(v)v=tostring(v or"");local row=rows[y]or string.rep(" ",W);v=v:sub(1,math.max(0,W-x+1));rows[y]=row:sub(1,x-1)..v..row:sub(x+#v);x=x+#v end

-- Pocket v8 must remap its existing remote-door action to the direct transport.
os={getComputerLabel=function()return"Pocket"end,getComputerID=function()return 77 end,time=function()return 12 end,epoch=function()return 1000 end}
for _,m in ipairs({"clients.pocket","clients.pocket_v8","clients.pocket_v7","clients.pocket_v6"})do package.loaded[m]=nil end
local pocket=assert(loadfile("clients/pocket.lua"))();pocket.init({})
local env={version="5.0.0-alpha.70",state={doors={doors={{id="D1",name="ROOM PANEL",_source="42",source="42",target="computer",side="left",open=false,online=true}}},power={},attachments={sensors={}},fleet={}}}
pocket.render(env,{connected=true})
local uiCalls={};local function uiAction(module,action,args)uiCalls[#uiCalls+1]={module=module,action=action,args=args};return true end
assert(pocket.handleEvent({"mouse_click",1,5,12},env,uiAction)==true,"Pocket tap not consumed")
assert(#uiCalls==1 and uiCalls[1].module=="direct_doors" and uiCalls[1].action=="open","Pocket did not choose direct door transport")
assert(tostring(uiCalls[1].args.source)=="42","Pocket lost room owner")

local function resetPackages()
 for _,m in ipairs({"roles.client_v4","roles.client_v3","core.network","core.module_loader","modules.doors"})do package.loaded[m]=nil end
end

-- Pocket-side client_v4: no local module scan, direct send to room, retry after
-- 0.25s, then surface the room's direct execution result as kimi_command_result.
resetPackages()
local sent={};local timerSeq=0;local timerDelays={};local events={}
local network={}
network.send=function(id,cfg,kind,payload)sent[#sent+1]={id=id,kind=kind,payload=payload};return true end
package.loaded["core.network"]=network
local rawReadCalls=0
local loader={readAll=function(modules,previous)rawReadCalls=rawReadCalls+1;return{shouldNot="run"}end}
package.loaded["core.module_loader"]=loader
local seenEvent
package.loaded["roles.client_v3"]={run=function(cfg)
 local state=loader.readAll({power={},ae2={},doors={}},{});assert(next(state)==nil,"Pocket local readAll was not suppressed")
 assert(network.send(999,cfg,"command",{module="direct_doors",action="open",args={source="42",target="computer",side="left",requestId="tap-1"}})==true)
 seenEvent={os.pullEvent()}
 return true
end}
os={
 getComputerID=function()return 77 end,epoch=function()return 2000 end,
 startTimer=function(delay)timerSeq=timerSeq+1;timerDelays[timerSeq]=delay;return timerSeq end,
 cancelTimer=function()end,
 pullEvent=function()
  if #events==0 then
   events={{"timer",1},{"rednet_message",42,{kind="door.command.direct.result",payload={requestId="tap-1",action="open",ok=true,result={open=true,target="computer",side="left"}}},"kimi-test"}}
  end
  local e=table.remove(events,1);return unpack(e)
 end
}
local client=assert(loadfile("roles/client_v4.lua"))()
assert(client.run({profile="pocket",network={protocol="kimi-test"}})==true,"Pocket client_v4 did not exit cleanly")
assert(rawReadCalls==0,"Pocket still ran hardware module polling")
local directCount=0
for _,s in ipairs(sent)do if s.kind=="door.command.direct"then directCount=directCount+1;assert(s.id==42,"direct command did not target owning room")end end
assert(directCount==2,"one missed direct packet did not retry automatically")
assert(timerDelays[1]==0.25 and timerDelays[2]==0.25,"direct retry cadence is not 0.25s")
assert(seenEvent and seenEvent[1]=="kimi_command_result" and seenEvent[2].ok==true and seenEvent[2].direct==true,"Pocket did not receive direct room confirmation")

-- Room-side client_v4: a direct packet from Pocket executes the local door handler
-- immediately and replies straight to Pocket. Wall polling must exclude power/AE2.
resetPackages()
local roomSent={};local roomNet={}
roomNet.send=function(id,cfg,kind,payload)roomSent[#roomSent+1]={id=id,kind=kind,payload=payload};return true end
package.loaded["core.network"]=roomNet
local filteredKeys
local roomLoader={readAll=function(modules,previous)filteredKeys={};for k in pairs(modules or{})do filteredKeys[k]=true end;return{doors={}}end}
package.loaded["core.module_loader"]=roomLoader
local doorCalls=0
package.loaded["modules.doors"]={
 read=function()return{localDoors={{target="computer",side="left",mode="invert"}}}end,
 handleCommand=function(action,args,state)doorCalls=doorCalls+1;assert(action=="open","room got wrong action");assert(tostring(args._source)=="42","room owner was not preserved");return{open=true,signal=false,target=args.target,side=args.side}end
}
local roomSeen
package.loaded["roles.client_v3"]={run=function(cfg)
 roomLoader.readAll({power={},ae2={},doors={},environment={},attachments={},system={}}, {})
 roomSeen={os.pullEvent()};return true
end}
local roomEvents={{"rednet_message",77,{kind="door.command.direct",payload={module="doors",action="open",requestId="tap-1",args={source="42",_source="42",target="computer",side="left",requestId="tap-1"}}},"kimi-test"},{"key",99}}
os={
 getComputerID=function()return 42 end,epoch=function()return 3000 end,startTimer=function()return 1 end,cancelTimer=function()end,
 pullEvent=function()local e=table.remove(roomEvents,1);return unpack(e)end
}
client=assert(loadfile("roles/client_v4.lua"))()
assert(client.run({profile="wall",network={protocol="kimi-test"}})==true,"room client_v4 did not exit cleanly")
assert(doorCalls==1,"room did not execute direct door packet exactly once")
assert(filteredKeys and filteredKeys.doors and filteredKeys.environment and filteredKeys.attachments and filteredKeys.system,"wall lean module set lost required modules")
assert(not filteredKeys.power and not filteredKeys.ae2,"wall client still scans power/AE2")
assert(roomSeen and roomSeen[1]=="key","direct room packet leaked into normal UI event loop")
assert(#roomSent==1 and roomSent[1].id==77 and roomSent[1].kind=="door.command.direct.result" and roomSent[1].payload.ok==true,"room did not reply directly to Pocket")

os=realOs
realPrint("alpha70 direct Pocket-to-room smoke test OK")
