local realPrint=print
local realOs=os
local realPackageLoaded=package.loaded

-- ---------------------------------------------------------------------------
-- 1) Main Base async transport: ONE Pocket click must stay alive by itself.
--    The first attempt times out, unrelated traffic still reaches the base
--    server, the retry is automatic, and the real room ACK completes it.
-- ---------------------------------------------------------------------------
local sends={}
local timerSeq=900
local liveTimers={}
local capturedRequestId=nil
local retryTimerId=nil
local baseSawUnrelated=false
local eventStep=0

package.loaded["core.network"]={
  send=function(target,cfg,kind,payload)
    sends[#sends+1]={target=target,kind=kind,payload=payload}
    if target==42 and kind=="module.command" then
      capturedRequestId=payload.requestId
    end
    return true
  end
}

package.loaded["roles.server_v2"]={
  run=function(cfg)
    local e1={os.pullEvent()}
    assert(e1[1]=="rednet_message" and e1[2]==99,"base server did not receive unrelated traffic while door transaction was pending")
    local msg=e1[3]
    assert(type(msg)=="table" and msg.kind=="ping","wrong unrelated event passed through")
    baseSawUnrelated=true

    local e2={os.pullEvent()}
    assert(e2[1]=="alpha66_done","async transport failed to consume its own retry/ACK events")
    return true
  end
}

os={
  getComputerID=function()return 1 end,
  epoch=function()return 123456 end,
  startTimer=function(seconds)
    timerSeq=timerSeq+1
    liveTimers[timerSeq]=seconds
    retryTimerId=timerSeq
    return timerSeq
  end,
  cancelTimer=function(id)liveTimers[id]=nil end,
  pullEvent=function()
    eventStep=eventStep+1
    if eventStep==1 then
      return "rednet_message",77,{kind="command",payload={module="remote_doors",action="open",args={source="42",target="redstone_integrator_0",side="east"}}},"kimi-test"
    elseif eventStep==2 then
      -- This MUST pass to the base server immediately. Alpha65 blocked here.
      return "rednet_message",99,{kind="ping",payload={}},"kimi-test"
    elseif eventStep==3 then
      assert(retryTimerId,"door transaction did not create a retry timer")
      return "timer",retryTimerId
    elseif eventStep==4 then
      assert(capturedRequestId,"door transaction never sent a requestId")
      return "rednet_message",42,{kind="module.command.result",payload={ok=true,module="doors",action="open",requestId=capturedRequestId,result={open=true,signal=false}}},"kimi-test"
    elseif eventStep==5 then
      return "alpha66_done"
    end
    error("unexpected extra pullEvent",0)
  end,
}

package.loaded["roles.server_v3"]=nil
local server=assert(loadfile("roles/server_v3.lua"))()
assert(server.run({network={protocol="kimi-test"}})==true,"server_v3 did not return cleanly")
assert(baseSawUnrelated==true,"base server was starved while remote door command was pending")

local roomSends={}
local pocketReply
for _,s in ipairs(sends)do
  if s.target==42 and s.kind=="module.command" then roomSends[#roomSends+1]=s end
  if s.target==77 and s.kind=="command.result" then pocketReply=s end
end
assert(#roomSends==2,"one Pocket click should have produced initial send + one automatic retry; got "..tostring(#roomSends))
assert(roomSends[1].payload.requestId==roomSends[2].payload.requestId,"retry changed requestId")
assert(roomSends[1].payload.action=="open" and roomSends[2].payload.action=="open","retry changed explicit OPEN intent")
assert(roomSends[1].payload.module=="doors" and roomSends[2].payload.module=="doors","destination did not receive local doors module")
assert(pocketReply and pocketReply.payload.ok==true and pocketReply.payload.confirmed==true,"Pocket requester never received confirmed success")
assert(pocketReply.payload.requestId==capturedRequestId,"Pocket confirmation lost transaction requestId")
assert(pocketReply.payload.attempts==2,"confirmation did not report automatic retry count")

-- ---------------------------------------------------------------------------
-- 2) Room client wrapper must echo Main Base requestId in module.command.result.
-- ---------------------------------------------------------------------------
local clientSent
package.loaded["core.network"]={
  send=function(target,cfg,kind,payload)
    clientSent={target=target,kind=kind,payload=payload}
    return true
  end
}

package.loaded["roles.client"]={
  run=function(cfg)
    local e={os.pullEvent()}
    assert(e[1]=="rednet_message" and e[2]==1,"client wrapper did not pass module.command to real client")
    local msg=e[3]
    assert(msg.kind=="module.command" and msg.payload.requestId=="REQ-66","client lost incoming requestId")
    local network=require("core.network")
    network.send(1,cfg,"module.command.result",{ok=true,module="doors",action="open",result={open=true}})
    return true
  end
}

local clientEventUsed=false
os={
  pullEvent=function()
    assert(not clientEventUsed,"client pulled more than one event")
    clientEventUsed=true
    return "rednet_message",1,{kind="module.command",payload={module="doors",action="open",requestId="REQ-66",args={_source="42",target="redstone_integrator_0",side="east"}}},"kimi-test"
  end
}

package.loaded["roles.client_v2"]=nil
local client=assert(loadfile("roles/client_v2.lua"))()
assert(client.run({network={protocol="kimi-test"}})==true,"client_v2 did not return cleanly")
assert(clientSent and clientSent.kind=="module.command.result","room client never sent command result")
assert(clientSent.payload.requestId=="REQ-66","room command result did not echo requestId")

os=realOs
realPrint("alpha66 async one-click door transaction smoke test OK")
