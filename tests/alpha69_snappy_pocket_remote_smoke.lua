local realPrint=print
local realOs=os

colors={white=1,orange=2,lightBlue=8,lime=32,gray=128,lightGray=256,cyan=512,blue=2048,red=16384,black=32768}
keys={left=203,right=205,one=2,two=3,three=4,four=5,five=6,six=7,seven=8,eight=9,nine=10}

-- ---------------------------------------------------------------------------
-- 1) Pocket must behave like a remote: immediate visible flip, immediate reverse
--    tap, unique request IDs, and stale results must not settle newer intent.
-- ---------------------------------------------------------------------------
local W,H=26,20
local rows,x,y={},1,1
term={getSize=function()return W,H end,setCursorPos=function(a,b)x,y=a,b end,setTextColor=function()end,setBackgroundColor=function()end,clear=function()rows={};x,y=1,1 end}
term.write=function(v)v=tostring(v or"");local row=rows[y]or string.rep(" ",W);v=v:sub(1,math.max(0,W-x+1));rows[y]=row:sub(1,x-1)..v..row:sub(x+#v);x=x+#v end
local function output()local o={};for i=1,H do o[i]=rows[i]or string.rep(" ",W)end;return table.concat(o,"\n")end
local epoch=1000
os={getComputerLabel=function()return"Pocket"end,getComputerID=function()return 77 end,time=function()return 12 end,epoch=function()return epoch end}
package.loaded["clients.pocket_v6"]=nil;package.loaded["clients.pocket_v7"]=nil;package.loaded["clients.pocket"]=nil
local pocket=assert(loadfile("clients/pocket.lua"))();pocket.init({})
local door={id="D1",name="ROOM PANEL",_source="42",source="42",target="redstone_integrator_0",side="east",open=false,online=true}
local env={version="5.0.0-alpha.69",state={doors={doors={door}},power={},attachments={sensors={}},fleet={}}}
local meta={connected=true}
pocket.render(env,meta)
assert(output():find("OPEN DOOR",1,true),"Pocket did not start CLOSED")

local calls={}
local function action(module,cmd,args)calls[#calls+1]={module=module,cmd=cmd,args=args};return true end
assert(pocket.handleEvent({"mouse_click",1,5,12},env,action)==true,"OPEN tap not consumed")
assert(#calls==1 and calls[1].cmd=="open","first tap did not send OPEN")
local req1=assert(calls[1].args.requestId,"OPEN has no requestId")
local out=output();assert(out:find("CLOSE DOOR",1,true)and out:find("OPEN",1,true),"OPEN tap did not flip UI instantly")
assert(not out:find("PLEASE WAIT",1,true)and not out:find("OPENING...",1,true),"Pocket still exposes WAIT/pending UI")

-- Telemetry is deliberately still CLOSED. The second tap must use the visible
-- local intent and immediately send CLOSE, not wait for ACK/state polling.
epoch=1010
assert(pocket.handleEvent({"mouse_click",1,5,12},env,action)==true,"rapid CLOSE tap not consumed")
assert(#calls==2 and calls[2].cmd=="close","rapid second tap did not send CLOSE")
local req2=assert(calls[2].args.requestId,"CLOSE has no requestId")
assert(req2~=req1,"rapid taps reused requestId")
out=output();assert(out:find("OPEN DOOR",1,true)and out:find("CLOSED",1,true),"rapid CLOSE did not flip UI back instantly")

-- The old OPEN transaction may now be reported as superseded. It must not touch
-- the newer CLOSE intent because request IDs are authoritative.
local stale={module="remote_doors",action="open",requestId=req1,ok=false,confirmed=false,error="superseded by newer door command",sourceId=42}
assert(pocket.handleEvent({"kimi_command_result",stale},env,action)==false,"stale OPEN result matched newer CLOSE intent")
out=output();assert(out:find("OPEN DOOR",1,true)and out:find("CLOSED",1,true),"stale OPEN result disturbed newest CLOSE state")

-- Matching CLOSE ACK confirms the newest intent. Because the stale raw telemetry
-- is also CLOSED, the ACK is what makes it safe to clear the local override.
local current={module="remote_doors",action="close",requestId=req2,ok=true,confirmed=true,sourceId=42,target="redstone_integrator_0",side="east",result={target="redstone_integrator_0",side="east",open=false}}
assert(pocket.handleEvent({"kimi_command_result",current},env,action)==true,"matching CLOSE ACK was not consumed")
out=output();assert(out:find("OPEN DOOR",1,true)and out:find("CLOSED",1,true),"confirmed CLOSE changed visible state incorrectly")

-- ---------------------------------------------------------------------------
-- 2) Main Base must preserve Pocket requestId and retry quickly without another
--    click. First attempt times out; second attempt succeeds at 0.35 s cadence.
-- ---------------------------------------------------------------------------
local sends={}
local timerSeq=900
local retryTimer
local timerSeconds={}
local eventStep=0

package.loaded["core.network"]={
 send=function(target,cfg,kind,payload)
  sends[#sends+1]={target=target,kind=kind,payload=payload}
  return true
 end
}
package.loaded["roles.server_v2"]={
 run=function(cfg)
  local e1={os.pullEvent()}
  assert(e1[1]=="rednet_message" and e1[2]==99 and e1[3].kind=="ping","server was blocked by pending door transaction")
  local e2={os.pullEvent()}
  assert(e2[1]=="alpha69_done","server leaked retry/ACK transport events")
  return true
 end
}
os={
 getComputerID=function()return 1 end,
 epoch=function()return 999999 end,
 cancelTimer=function()end,
 startTimer=function(sec)
  timerSeq=timerSeq+1;retryTimer=timerSeq;timerSeconds[#timerSeconds+1]=sec;return timerSeq
 end,
 pullEvent=function()
  eventStep=eventStep+1
  if eventStep==1 then
   return"rednet_message",77,{kind="command",payload={module="remote_doors",action="open",args={source="42",target="redstone_integrator_0",side="east",requestId="REQ-69"}}},"kimi-test"
  elseif eventStep==2 then
   return"rednet_message",99,{kind="ping",payload={}},"kimi-test"
  elseif eventStep==3 then
   assert(retryTimer,"server did not create retry timer")
   return"timer",retryTimer
  elseif eventStep==4 then
   return"rednet_message",42,{kind="module.command.result",payload={ok=true,module="doors",action="open",requestId="REQ-69",result={open=true,signal=false,target="redstone_integrator_0",side="east"}}},"kimi-test"
  elseif eventStep==5 then
   return"alpha69_done"
  end
  error("unexpected event step "..tostring(eventStep),0)
 end,
}
package.loaded["roles.server_v3"]=nil
local server=assert(loadfile("roles/server_v3.lua"))()
assert(server.run({network={protocol="kimi-test"}})==true,"server_v3 did not return cleanly")

local roomSends,pocketReply={},nil
for _,s in ipairs(sends)do
 if s.target==42 and s.kind=="module.command"then roomSends[#roomSends+1]=s end
 if s.target==77 and s.kind=="command.result"then pocketReply=s end
end
assert(#roomSends==2,"one click should have initial send + one automatic retry")
assert(roomSends[1].payload.requestId=="REQ-69" and roomSends[2].payload.requestId=="REQ-69","Main Base replaced Pocket requestId")
assert(roomSends[1].payload.action=="open"and roomSends[2].payload.action=="open","retry changed explicit intent")
assert(#timerSeconds>=2 and math.abs(timerSeconds[1]-.35)<.001 and math.abs(timerSeconds[2]-.35)<.001,"door retry cadence is not 0.35 seconds")
assert(pocketReply and pocketReply.payload.ok==true and pocketReply.payload.requestId=="REQ-69","Pocket did not receive matching confirmed result")
assert(pocketReply.payload.target=="redstone_integrator_0"and pocketReply.payload.side=="east","final result lost actuator identity")

os=realOs
realPrint("alpha69 snappy Pocket remote smoke test OK")
