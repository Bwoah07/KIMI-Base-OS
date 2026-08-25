local realPrint=print
colors={white=1,orange=2,lightBlue=8,lime=32,gray=128,lightGray=256,cyan=512,blue=2048,red=16384,black=32768}
keys={left=203,right=205,one=2,two=3,three=4,four=5,five=6,six=7,seven=8,eight=9,nine=10}

-- Pocket boots directly into a clean door-control screen and shows real pending state.
local W,H=26,20
local rows,x,y={},1,1
term={getSize=function()return W,H end,setCursorPos=function(a,b)x,y=a,b end,setTextColor=function()end,setBackgroundColor=function()end,clear=function()rows={};x,y=1,1 end}
term.write=function(v)v=tostring(v or"");local row=rows[y]or string.rep(" ",W);v=v:sub(1,math.max(0,W-x+1));rows[y]=row:sub(1,x-1)..v..row:sub(x+#v);x=x+#v end
local function output()local o={};for i=1,H do o[i]=rows[i]or string.rep(" ",W)end;return table.concat(o,"\n")end
local epoch=1000
os={getComputerLabel=function()return"Pocket"end,getComputerID=function()return 77 end,time=function()return 12 end,epoch=function()return epoch end}
package.loaded["clients.pocket_v5"]=nil;package.loaded["clients.pocket_v6"]=nil;package.loaded["clients.pocket_v7"]=nil;package.loaded["clients.pocket"]=nil
local pocket=assert(loadfile("clients/pocket.lua"))();pocket.init({})
local env={version="5.0.0-alpha.68",state={doors={doors={{id="D1",name="ROOM PANEL",_source="42",source="42",target="computer",side="left",open=false,online=true}}},power={stored=500,capacity=1000,filledPercentage=.5},attachments={sensors={}},fleet={}}}
local meta={connected=true}
pocket.render(env,meta)
local out=output()
assert(out:find("DOOR CONTROL",1,true)and out:find("ROOM PANEL",1,true)and out:find("OPEN DOOR",1,true),"Pocket did not boot into direct door control")
assert(not out:find("QUICK DOOR",1,true)and not out:find("BASE ONLINE",1,true),"Pocket still has old dashboard clutter")
local calls={};local function action(module,cmd,args)calls[#calls+1]={module=module,cmd=cmd,args=args};return true end
pocket.handleEvent({"mouse_click",1,5,12},env,action)
assert(#calls==1 and calls[1].cmd=="open","Pocket giant button did not send OPEN")
out=output();assert(out:find("OPENING...",1,true)and out:find("PLEASE WAIT",1,true),"Pocket did not show OPENING pending state")
pocket.handleEvent({"kimi_command_result",{module="remote_doors",action="open",ok=true,confirmed=true,sourceId=42,result={target="computer",side="left",open=true}}},env,action)
out=output();assert(out:find("CLOSE DOOR",1,true)and out:find("OPEN",1,true),"Pocket did not settle confirmed OPEN immediately")

-- Admin power monitor: Matrix wins, gauge is narrow, and ETA status reflects net flow.
local function surface(w,h)
 local textRows,cx,cy,bg={},1,1,colors.black
 local s={_bg={}}
 s.setTextScale=function()end;s.setBackgroundColor=function(v)bg=v end;s.setTextColor=function()end
 s.clear=function()textRows={};s._bg={};cx,cy=1,1 end;s.setCursorPos=function(a,b)cx,cy=a,b end;s.getSize=function()return w,h end
 s.write=function(v)v=tostring(v or"");if cy<1 or cy>h or cx>w then return end;v=v:sub(1,math.max(0,w-cx+1));local row=textRows[cy]or string.rep(" ",w);textRows[cy]=row:sub(1,cx-1)..v..row:sub(cx+#v);for i=0,#v-1 do s._bg[cy]=s._bg[cy]or{};s._bg[cy][cx+i]=bg end;cx=cx+#v end
 s.output=function()local o={};for i=1,h do o[i]=textRows[i]or string.rep(" ",w)end;return table.concat(o,"\n")end
 s.maxColorWidth=function(color)local max=0;for _,cells in pairs(s._bg)do local n=0;for _,c in pairs(cells)do if c==color then n=n+1 end end;if n>max then max=n end end;return max end
 return s
end
local main=surface(68,30);local powerMon=surface(25,30);local fleetMon=surface(25,30)
local devices={main={type="monitor",object=main},left={type="monitor",object=powerMon},right={type="monitor",object=fleetMon}}
peripheral={getNames=function()return{"main","left","right"}end,getType=function(n)return devices[n].type end,hasType=function(n,t)return devices[n]and devices[n].type==t end,wrap=function(n)return devices[n]and devices[n].object end}
term={setBackgroundColor=function()end,setTextColor=function()end,clear=function()end,setCursorPos=function()end,write=function()end}
os.getComputerLabel=function()return"Main Base"end;os.time=function()return 20 end
package.loaded["clients.admin_v15"]=nil;package.loaded["clients.admin_v12"]=nil;package.loaded["clients.admin"]=nil
local admin=assert(loadfile("clients/admin.lua"))();admin.init({name="Main Base"})
local p={stored=500,capacity=1000,input=20,output=10,net=10,filledPercentage=.5}
local aenv={version="5.0.0-alpha.68",state={doors={doors={}},power={matrices={p},fluxNetworks={{stored=1000,capacity=1000,filledPercentage=1}}},attachments={sensors={}},fleet={}}}
assert(admin.render(aenv,{localServer=true})~=false,"admin v15 render failed")
local text=powerMon.output();assert(text:find("FULL IN",1,true),"charging Matrix did not show time to full")
local greenWidth=powerMon.maxColorWidth(colors.lime);assert(greenWidth>=5 and greenWidth<=7,"Matrix gauge is not narrow enough: "..tostring(greenWidth))
p.input=10;p.output=20;p.net=-10;assert(admin.render(aenv,{localServer=true})~=false,"drain render failed");text=powerMon.output();assert(text:find("EMPTY IN",1,true),"draining Matrix did not show time to empty")
p.input=1000;p.output=999;p.net=1;assert(admin.render(aenv,{localServer=true})~=false,"holding render failed");text=powerMon.output();assert(text:find("HOLDING",1,true),"near-balanced Matrix did not show HOLDING")
realPrint("alpha61 power ETA/Pocket smoke test OK")
