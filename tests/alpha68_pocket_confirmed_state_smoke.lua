local realPrint=print
local realOs=os
colors={white=1,orange=2,lightBlue=8,lime=32,gray=128,lightGray=256,cyan=512,blue=2048,red=16384,black=32768}
keys={left=203,right=205,one=2,two=3,three=4,four=5,five=6,six=7,seven=8,eight=9,nine=10}

local W,H=26,20
local rows,x,y={},1,1
term={getSize=function()return W,H end,setCursorPos=function(a,b)x,y=a,b end,setTextColor=function()end,setBackgroundColor=function()end,clear=function()rows={};x,y=1,1 end}
term.write=function(v)v=tostring(v or"");local row=rows[y]or string.rep(" ",W);v=v:sub(1,math.max(0,W-x+1));rows[y]=row:sub(1,x-1)..v..row:sub(x+#v);x=x+#v end
local function output()local o={};for i=1,H do o[i]=rows[i]or string.rep(" ",W)end;return table.concat(o,"\n")end

local epoch=1000
os={getComputerLabel=function()return"Pocket"end,getComputerID=function()return 77 end,time=function()return 12 end,epoch=function()return epoch end}
package.loaded["clients.pocket_v6"]=nil;package.loaded["clients.pocket_v7"]=nil;package.loaded["clients.pocket"]=nil
local pocket=assert(loadfile("clients/pocket.lua"))();pocket.init({})
local env={version="5.0.0-alpha.69",state={doors={doors={{id="D1",name="ROOM PANEL",_source="42",source="42",target="redstone_integrator_0",side="east",open=false,online=true}}},power={},attachments={sensors={}},fleet={}}}
local meta={connected=true}
pocket.render(env,meta)
assert(output():find("OPEN DOOR",1,true),"closed door did not start with OPEN control")

local calls={}
local function action(module,cmd,args)calls[#calls+1]={module=module,cmd=cmd,args=args};return true end
assert(pocket.handleEvent({"mouse_click",1,5,12},env,action)==true,"first tap not consumed")
assert(#calls==1 and calls[1].module=="remote_doors" and calls[1].cmd=="open","first tap did not send OPEN")
local req1=assert(calls[1].args.requestId,"Pocket command has no requestId")
local out=output();assert(out:find("CLOSE DOOR",1,true)and out:find("OPEN",1,true),"Pocket did not flip OPEN immediately")
assert(not out:find("PLEASE WAIT",1,true),"Pocket still blocks on confirmation")

-- A real room ACK still reaches the profile and must be accepted by exact requestId.
local result={module="remote_doors",action="open",requestId=req1,ok=true,confirmed=true,sourceId=42,target="redstone_integrator_0",side="east",result={target="redstone_integrator_0",side="east",open=true,signal=false}}
assert(pocket.handleEvent({"kimi_command_result",result},env,action)==true,"final command result was not consumed")
out=output();assert(out:find("CLOSE DOOR",1,true)and out:find("OPEN",1,true),"successful ACK disturbed visible OPEN intent")

-- The live client wrapper must still turn Main Base command.result packets into
-- the profile event instead of silently dropping them.
local seen
package.loaded["roles.client_v2"]={run=function(cfg)local e={os.pullEvent()};seen=e;return true end}
os={pullEvent=function()return"rednet_message",1,{kind="command.result",payload={module="remote_doors",action="open",requestId=req1,ok=true,confirmed=true}},"kimi-test"end}
package.loaded["roles.client_v3"]=nil
local client=assert(loadfile("roles/client_v3.lua"))()
assert(client.run({network={protocol="kimi-test"}})==true,"client_v3 did not return cleanly")
assert(seen and seen[1]=="kimi_command_result" and seen[2].requestId==req1,"client still dropped/corrupted final command.result")

os=realOs
realPrint("alpha68 Pocket confirmed-state bridge smoke test OK")
