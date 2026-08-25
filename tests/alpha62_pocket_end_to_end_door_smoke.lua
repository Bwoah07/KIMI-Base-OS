local realPrint=print
colors={white=1,orange=2,lightBlue=8,lime=32,gray=128,lightGray=256,cyan=512,blue=2048,red=16384,black=32768}
keys={left=203,right=205,one=2,two=3,three=4,four=5,six=7,seven=8,eight=9,nine=10}

-- 1) Pocket tap originates remote_doors OPEN without using reserved _source.
local W,H=26,20;local rows,x,y={},1,1
term={getSize=function()return W,H end,setCursorPos=function(a,b)x,y=a,b end,setTextColor=function()end,setBackgroundColor=function()end,clear=function()rows={};x,y=1,1 end}
term.write=function(v)v=tostring(v or"");local row=rows[y]or string.rep(" ",W);v=v:sub(1,math.max(0,W-x+1));rows[y]=row:sub(1,x-1)..v..row:sub(x+#v);x=x+#v end
os={getComputerLabel=function()return"Pocket"end,getComputerID=function()return 77 end,time=function()return 12 end,epoch=function()return 1000 end}
package.loaded["clients.pocket_v5"]=nil;package.loaded["clients.pocket"]=nil
local pocket=assert(loadfile("clients/pocket.lua"))();pocket.init({})
local env={version="5.0.0-alpha.63",state={doors={doors={{id="D1",name="ROOM PANEL",_source="42",source="42",target="computer",side="left",open=false,online=true}}},power={},attachments={sensors={}},fleet={}}}
pocket.render(env,{connected=true})
local requested
local function pocketAction(module,action,args)requested={module=module,action=action,args=args};return true,{queued=true}end
assert(pocket.handleEvent({"mouse_click",1,5,12},env,pocketAction)==true,"Pocket did not consume door tap")
assert(requested and requested.module=="remote_doors" and requested.action=="open","Pocket did not request remote OPEN")
assert(requested.args._source==nil and tostring(requested.args.source)=="42" and requested.args.target=="computer" and requested.args.side=="left","Pocket lost safe owner/actuator routing")

-- 2) The actual remote router resolves room 42 and sends module='doors'.
local forwarded
package.loaded["core.network"]={send=function(target,cfg,kind,payload)forwarded={target=target,kind=kind,payload=payload};return true end}
package.loaded["core.config"]={load=function()return{network={protocol="kimi-test"}}end}
package.loaded["modules.remote_doors"]=nil
os.getComputerID=function()return 1 end
local router=assert(loadfile("modules/remote_doors.lua"))()
local routeResult=router.handleCommand(requested.action,requested.args)
assert(routeResult and routeResult.queued==true and routeResult.sourceId==42,"remote router did not queue room command")
assert(forwarded and forwarded.target==42 and forwarded.kind=="module.command","Main Base targeted wrong room computer")
assert(forwarded.payload.module=="doors","remote router did not terminate at local doors module")
assert(forwarded.payload.action=="open","remote router lost OPEN action")
assert(tostring(forwarded.payload.args._source)=="42","remote router did not add destination ownership")

-- 3) Room PC local doors module uses saved inverted config and writes redstone.
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

realPrint("alpha62 Pocket -> remote router -> room door smoke test OK")
