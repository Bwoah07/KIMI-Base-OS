local realPrint=print
colors={white=1,orange=2,lightBlue=8,lime=32,gray=128,lightGray=256,cyan=512,blue=2048,red=16384,black=32768}

local function surface(w,h)
 local textRows,cx,cy,bg={},1,1,colors.black
 local s={_bg={}}
 s.setTextScale=function()end;s.setBackgroundColor=function(v)bg=v end;s.setTextColor=function()end
 s.clear=function()textRows={};s._bg={};cx,cy=1,1 end;s.setCursorPos=function(a,b)cx,cy=a,b end;s.getSize=function()return w,h end
 s.write=function(v)v=tostring(v or"");if cy<1 or cy>h or cx>w then return end;v=v:sub(1,math.max(0,w-cx+1));local row=textRows[cy]or string.rep(" ",w);textRows[cy]=row:sub(1,cx-1)..v..row:sub(cx+#v);for i=0,#v-1 do s._bg[cy]=s._bg[cy]or{};s._bg[cy][cx+i]=bg end;cx=cx+#v end
 s.countColor=function(color)local rows,maxWidth,first,last=0,0,nil,nil;for yy=1,h do local n=0;for _,c in pairs(s._bg[yy]or{})do if c==color then n=n+1 end end;if n>0 then rows=rows+1;maxWidth=math.max(maxWidth,n);first=first or yy;last=yy end end;return rows,maxWidth,first,last end
 return s
end

local main=surface(68,30);local powerMon=surface(25,30);local fleetMon=surface(25,30)
local devices={main={type="monitor",object=main},left={type="monitor",object=powerMon},right={type="monitor",object=fleetMon}}
peripheral={getNames=function()return{"main","left","right"}end,getType=function(n)return devices[n].type end,hasType=function(n,t)return devices[n]and devices[n].type==t end,wrap=function(n)return devices[n]and devices[n].object end}
term={setBackgroundColor=function()end,setTextColor=function()end,clear=function()end,setCursorPos=function()end,write=function()end}
os={getComputerLabel=function()return"Main Base"end,time=function()return 12 end}
package.loaded["clients.admin_v13"]=nil;package.loaded["clients.admin_v12"]=nil;package.loaded["clients.admin"]=nil
local admin=assert(loadfile("clients/admin.lua"))();admin.init({name="Main Base"})
local env={version="5.0.0-alpha.59",state={doors={doors={}},power={stored=1000,capacity=1000,input=100,output=25,filledPercentage=1},attachments={sensors={}},fleet={}}}
assert(admin.render(env,{localServer=true})~=false,"alpha59 admin render failed")
local limeRows,limeWidth,limeFirst,limeLast=powerMon.countColor(colors.lime)
local shellRows,shellWidth=powerMon.countColor(colors.gray)
assert(limeRows>=12 and limeLast-limeFirst+1==limeRows,"100% battery fill must be continuous, not shelves")
assert(limeWidth>=8 and limeWidth<=11,"battery inner fill has wrong width")
assert(shellRows>=14 and shellWidth>=12,"battery lost its framed shell/cap silhouette")

-- Low charge switches the same continuous chamber to red rather than changing shape.
env.state.power.stored=200;env.state.power.filledPercentage=.2
assert(admin.render(env,{localServer=true})~=false,"low-charge battery render failed")
local redRows,redWidth=powerMon.countColor(colors.red)
assert(redRows>=2 and redWidth>=8,"low battery did not render a visible red charge fill")
realPrint("alpha59 battery shape smoke test OK")
