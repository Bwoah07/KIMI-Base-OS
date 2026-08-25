local realPrint=print
local realOs=os

local sends={}
package.loaded["core.network"]={
  send=function(target,cfg,kind,payload)
    sends[#sends+1]={target=target,kind=kind,payload=payload}
    return true
  end
}
package.loaded["core.config"]={load=function()return{network={protocol="kimi-test"}}end}

local timers=100
local queued={}
local events={
  -- Unrelated traffic must survive the synchronous ACK wait.
  {"rednet_message",77,{kind="telemetry.state",payload={hello=true}},"kimi-test"},
  -- First OPEN attempt times out.
  {"timer",101},
  -- Second OPEN attempt receives the room computer's actual execution result.
  {"rednet_message",42,{kind="module.command.result",payload={ok=true,result={open=true,signal=false},module="doors",action="open",sourceId=42}},"kimi-test"},
}
local eventIndex=0
os={
  getComputerID=function()return 1 end,
  epoch=function()return 1000 end,
  startTimer=function()timers=timers+1;return timers end,
  cancelTimer=function()end,
  pullEvent=function()
    eventIndex=eventIndex+1
    local e=events[eventIndex]
    if not e then error("test event queue exhausted")end
    return unpack(e)
  end,
  queueEvent=function(...)
    queued[#queued+1]={...}
  end,
}

package.loaded["modules.remote_doors"]=nil
local remote=assert(loadfile("modules/remote_doors.lua"))()
local result=remote.handleCommand("open",{source="42",target="redstone_integrator_0",side="east"})
assert(result and result.confirmed==true,"remote door returned before real room confirmation")
assert(result.sourceId==42,"remote door confirmed wrong room")
assert(result.attempts==2,"OPEN was not retried exactly once after first timeout")
assert(result.result and result.result.open==true,"actual room execution result was lost")
assert(#sends==2,"expected two idempotent OPEN sends, got "..tostring(#sends))
for i,s in ipairs(sends)do
  assert(s.target==42 and s.kind=="module.command","attempt "..i.." targeted wrong packet")
  assert(s.payload.module=="doors" and s.payload.action=="open","attempt "..i.." changed explicit OPEN")
  assert(tostring(s.payload.args._source)=="42","attempt "..i.." lost destination ownership")
end
assert(#queued==1 and queued[1][1]=="rednet_message" and queued[1][2]==77,"unrelated rednet traffic was swallowed during ACK wait")

os=realOs
realPrint("alpha65 reliable remote door ACK/retry smoke test OK")
