local realPrint=print
colors={white=1,orange=2,lightGray=256,cyan=512,lightBlue=8,lime=32,red=16384,black=32768,gray=128,blue=2048}
keys={left=203,right=205,one=2,two=3,three=4,four=5,five=6,six=7,seven=8,eight=9,nine=10}
local rows,x,y={},1,1
term={}
term.getSize=function()return 26,20 end
term.setCursorPos=function(a,b)x,y=a,b end
term.setTextColor=function()end
term.setBackgroundColor=function()end
term.clear=function()rows={};x,y=1,1 end
term.write=function(v)v=tostring(v or"");local row=rows[y]or string.rep(" ",26);v=v:sub(1,math.max(0,26-x+1));rows[y]=row:sub(1,x-1)..v..row:sub(x+#v);x=x+#v end
local function output()local t={};for i=1,20 do t[i]=rows[i]or string.rep(" ",26)end;return table.concat(t,"\n")end
os={getComputerLabel=function()return"Pocket Boss"end,getComputerID=function()return 77 end,time=function()return 12 end,epoch=function()return 1 end}

local env={version="5.0.0-alpha.46",state={
 doors={doors={{id="local:42|computer|left",name="VAULT",_source="42",source="42",target="computer",side="left",open=false,online=true}}},
 attachments={sensors={{type="environment_detector",metrics={temperature=21.5}}}},
 power={stored=750,capacity=1000,input=50,output=10,filledPercentage=.75},
 fleet={[1]={online=true,version="5.0.0-alpha.46",name="Main Base"},[42]={online=true,version="5.0.0-alpha.46",name="Vault Room"},[77]={online=true,version="5.0.0-alpha.46",name="Pocket Boss"}}
}}
local meta={connected=true,localVersion="5.0.0-alpha.46"}
local p=assert(loadfile("clients/pocket.lua"))();p.init({});p.render(env,meta)
assert(output():find("JUICE",1,true),"pocket home lost juice/power")
-- go to doors
p.handleEvent({"key",keys.right},env,function()return true end)
local out=output();assert(out:find("VAULT",1,true),"pocket doors page lost configured door")
local called
p.handleEvent({"mouse_click",1,3,6},env,function(module,action,args)called={module=module,action=action,args=args};return true,{queued=true}end)
assert(called,"pocket click did not issue a command")
assert(called.module=="remote_doors" and called.action=="toggle","pocket did not use remote door router")
assert(tostring(called.args._source)=="42" and called.args.target=="computer" and called.args.side=="left","pocket lost door owner/actuator routing")

-- Remote router must forward through Main Base to the owning controller computer.
package.loaded["core.network"]={send=function(target,cfg,kind,payload)
 assert(target==42,"remote router targeted wrong computer")
 assert(kind=="module.command","remote router used wrong packet kind")
 assert(payload.module=="doors" and payload.action=="toggle","remote router lost door command")
 return true
end}
package.loaded["core.config"]={load=function()return{network={protocol="kimi_base_os_v1"}}end}
package.loaded["modules.remote_doors"]=nil
local r=assert(loadfile("modules/remote_doors.lua"))()
local result=r.handleCommand("toggle",{_source="42",target="computer",side="left"})
assert(result and result.queued==true and result.sourceId==42,"remote router did not report queued command")

local f=assert(io.open("modules/doors.lua","r"));local src=f:read("*a");f:close()
assert(src:find("table.unpack",1,true) and src:find("_G.unpack",1,true),"door wrapper lacks CC:Tweaked unpack compatibility")
realPrint("alpha46 pocket remote smoke test OK")
