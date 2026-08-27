local realPrint=print
colors={white=1,orange=2,lightBlue=8,lime=32,gray=128,lightGray=256,cyan=512,blue=2048,red=16384,black=32768}

local function surface(w,h)
 local textRows,cx,cy,bg={},1,1,colors.black;local s={_bg={}}
 s.setTextScale=function()end;s.setBackgroundColor=function(v)bg=v end;s.setTextColor=function()end;s.clear=function()textRows={};s._bg={};cx,cy=1,1 end;s.setCursorPos=function(a,b)cx,cy=a,b end;s.getSize=function()return w,h end
 s.write=function(v)v=tostring(v or"");if cy<1 or cy>h or cx>w then return end;v=v:sub(1,math.max(0,w-cx+1));local row=textRows[cy]or string.rep(" ",w);textRows[cy]=row:sub(1,cx-1)..v..row:sub(cx+#v);for i=0,#v-1 do s._bg[cy]=s._bg[cy]or{};s._bg[cy][cx+i]=bg end;cx=cx+#v end
 s.countColor=function(color)local rows,maxWidth,first,last=0,0,nil,nil;for yy=1,h do local n=0;for _,c in pairs(s._bg[yy]or{})do if c==color then n=n+1 end end;if n>0 then rows=rows+1;maxWidth=math.max(maxWidth,n);first=first or yy;last=yy end end;return rows,maxWidth,first,last end
 s.output=function()local out={};for i=1,h do out[i]=textRows[i]or string.rep(" ",w)end;return table.concat(out,"\n")end
 return s
end
local main=surface(68,30);local powerMon=surface(25,30);local fleetMon=surface(25,30)
local devices={main={type="monitor",object=main},left={type="monitor",object=powerMon},right={type="monitor",object=fleetMon}}
peripheral={getNames=function()return{"main","left","right"}end,getType=function(n)return devices[n].type end,hasType=function(n,t)return devices[n]and devices[n].type==t end,wrap=function(n)return devices[n]and devices[n].object end}
term={setBackgroundColor=function()end,setTextColor=function()end,clear=function()end,setCursorPos=function()end,write=function()end};os={getComputerLabel=function()return"Main Base"end,time=function()return 12 end}
package.loaded["clients.admin_v15"]=nil;package.loaded["clients.admin_v16"]=nil;package.loaded["clients.admin_v17"]=nil;package.loaded["clients.admin_v12"]=nil;package.loaded["clients.admin"]=nil
local admin=assert(loadfile("clients/admin.lua"))();admin.init({name="Main Base"})
local matrix={stored=1000,capacity=1000,input=100,output=25,filledPercentage=1,peripheral="main_matrix"}
local env={version="5.0.0-alpha.71",state={doors={doors={}},environment={online=true,weather="CLEAR"},power={matrices={matrix},fluxNetworks={{networkName="GRID",stored=1000,net=75}}},power_reserve={status="NO RESERVE MATRIX"},attachments={devices={},sensors={}},fleet={}}}
assert(admin.render(env,{localServer=true})~=false,"admin render failed")
local limeRows,limeWidth,limeFirst,limeLast=powerMon.countColor(colors.lime);local shellRows,shellWidth=powerMon.countColor(colors.gray)
-- Alpha71 intentionally shortens the Matrix tank to make room for reserve and
-- Flux telemetry. Preserve the useful contract: a full charge is a continuous,
-- narrow green tank with a visible shell.
assert(limeRows>=5 and limeLast-limeFirst+1==limeRows,"100% Matrix fill must remain continuous")
assert(limeWidth>=5 and limeWidth<=7,"Matrix fill width regressed")
assert(shellRows>=7 and shellWidth>=7 and shellWidth<=9,"Matrix border width regressed")
local text=powerMon.output();assert(text:find("FLUX NETWORKS",1,true)and text:find("GRID",1,true),"power panel lost Flux telemetry")
matrix.stored=200;matrix.filledPercentage=.2;assert(admin.render(env,{localServer=true})~=false,"low-charge render failed")
local lowRows,lowWidth=powerMon.countColor(colors.lime);local redRows=powerMon.countColor(colors.red)
assert(lowRows>=1 and lowRows<limeRows and lowWidth>=5,"20% charge did not reduce green fill");assert(redRows==0,"Matrix tank must stay green rather than become an alarm block")
realPrint("alpha59 battery shape compatibility test OK")
