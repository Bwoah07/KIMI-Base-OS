local realPrint=print
colors={white=1,orange=2,lightBlue=8,lime=32,gray=128,lightGray=256,cyan=512,blue=2048,red=16384,black=32768}
keys={left=203,right=205,one=2,two=3,three=4,four=5,six=7,seven=8,eight=9,nine=10}

-- 1) Pocket tap must originate a remote_doors OPEN command for the owning room PC.
local W,H=26,20;local rows,x,y={},1,1
term={getSize=function()return W,H end,setCursorPos=function(a,b)x,y=a,b end,setTextColor=function()end,setBackgroundColor=function()end,clear=function()rows={};x,y=1,1 end}
term.write=function(v)v=tostring(v or"");local row=rows[y]or string.rep(" ",W);v=v:sub(1,math.max(0,W-x+1));rows[y]=row:sub(1,x-1)..v..row:sub(x+#v);x=x+#v end
os={getComputerLabel=function()return"Pocket"end,getComputerID=function()return 77 end,time=function()return 12 end,epoch=function()return 1000 end}
package.loaded["clients.pocket_v5"]=nil;package.loaded["clients.pocket"]=nil
local pocket=assert(loadfile("clients/pocket.lua"))();pocket.init({})
local env={version="5.0.0-alpha.62",state={doors={doors={{id="D1",name="ROOM PANEL",_source="42",source="42",target="computer",side="left",open=false,online=true}}},power={},attachments={sensors={}},fleet={}}}
pocket.render(env,{connected=true})
local requested
local function pocketAction(module,action,args)requested={module=module,action=action,args=args};return true,{queued=true}end
assert(pocket.handleEvent({"mouse_click",1,5,12},env,pocketAction)==true,"Pocket did not consume door tap")
assert(requested and requested.module=="remote_doors" and requested.action=="open","Pocket did not request remote OPEN")
assert(tostring(requested.args._source)=="42" and requested.args.target=="computer" and requested.args.side=="left","Pocket lost owner/actuator routing")

-- 2) Main Base server_v2 must terminate remote routing: destination receives module='doors'.
local forwarded
package.loaded["core.network"]={send=function(target,cfg,kind,payload)forwarded={target=target,kind=kind,payload=payload};return true end}
package.loaded["core.update_service"]={releaseNotice=function()return{version="5.0.0-alpha.62",manifest={},issuedBy=1}end}
package.loaded["roles.server"]={run=function(cfg)
 local network=require("core.network")
 return network.send(42,cfg,"module.command",{module=requested.module,action=requested.action,args=requested.args,issuedBy=1})
end}
package.loaded["roles.server_v2"]=nil
local server=assert(loadfile("roles/server_v2.lua"))();assert(server.run({})==true,"server wrapper did not forward command")
assert(forwarded and forwarded.target==42 and forwarded.kind=="module.command","Main Base targeted wrong room computer")
assert(forwarded.payload.module=="doors","Main Base forwarded remote_doors instead of local doors")
assert(forwarded.payload.action=="open" and forwarded.payload.args==requested.args,"Main Base changed door command payload")

-- 3) Room PC local doors module must use its saved inverted config and write redstone.
local physical=nil
redstone={setOutput=function(side,value)assert(side=="left","wrong redstone side");physical=value end,getOutput=function()return true end}
sleep=function()end
package.loaded["core.doors_impl"]={handleCommand=function()error("configured door fell through to generic implementation")end}
package.loaded["modules.doors"]=nil
local doors=assert(loadfile("modules/doors.lua"))()
local saved={localDoors={{target="computer",side="left",kind="digital_side",mode="invert",open=false,signal=true}}}
local result=doors.handleCommand(forwarded.payload.action,forwarded.payload.args,saved)
assert(result and result.open==true,"room door did not become logically OPEN")
assert(physical==false,"INVERTED room door OPEN must drive physical redstone OFF")

realPrint("alpha62 Pocket -> Main Base -> room door end-to-end smoke test OK")
