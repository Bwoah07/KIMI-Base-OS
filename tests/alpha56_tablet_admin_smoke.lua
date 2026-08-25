local realPrint=print
colors={white=1,orange=2,lightBlue=8,lime=32,gray=128,lightGray=256,cyan=512,blue=2048,red=16384,black=32768}
keys={left=203,right=205,one=2,two=3,three=4,four=5,five=6,six=7,seven=8,eight=9,nine=10}

-- Pocket: explicit OPEN/CLOSE with local shadow state while telemetry is stale.
local W,H=26,20
local rows,x,y={},1,1
term={getSize=function()return W,H end,setCursorPos=function(a,b)x,y=a,b end,setTextColor=function()end,setBackgroundColor=function()end,clear=function()rows={};x,y=1,1 end}
term.write=function(v)v=tostring(v or"");local row=rows[y]or string.rep(" ",W);v=v:sub(1,math.max(0,W-x+1));rows[y]=row:sub(1,x-1)..v..row:sub(x+#v);x=x+#v end
local epoch=1000
os={getComputerLabel=function()return"Pocket"end,getComputerID=function()return 77 end,time=function()return 12 end,epoch=function()return epoch end}
package.loaded["clients.pocket_v2"]=nil
package.loaded["clients.pocket"]=nil
local p=assert(loadfile("clients/pocket.lua"))();p.init({})
local env={version="5.0.0-alpha.56",state={doors={doors={{id="D1",name="VAULT",_source="42",target="computer",side="left",open=true,online=true}}},power={stored=800,capacity=1000,input=50,output=20,filledPercentage=.8},attachments={sensors={}},fleet={}}}
local meta={connected=true}
p.render(env,meta)
p.handleEvent({"key",keys.right},env,function()return true end)
local calls={}
local function action(module,cmd,args)calls[#calls+1]={module=module,cmd=cmd,args=args};return true,{queued=true}end
p.handleEvent({"mouse_click",1,3,6},env,action)
assert(#calls==1 and calls[1].module=="remote_doors" and calls[1].cmd=="close","open door did not send explicit CLOSE")
-- Telemetry is intentionally still OPEN. After debounce, another tap must reverse the pending state and send OPEN.
epoch=1400
p.handleEvent({"mouse_click",1,3,6},env,action)
assert(#calls==2 and calls[2].cmd=="open","stale telemetry made pocket send CLOSE twice")

-- Admin: center is clock + door state, second monitor is vertical power, third is fleet/version.
local function surface(w,h)
 local textRows={},cx,cy,bg={},1,1,colors.black
 local s={}
 s.setTextScale=function()end
 s.setBackgroundColor=function(v)bg=v end
 s.setTextColor=function()end
 s.clear=function()textRows={};cx,cy=1,1 end
 s.setCursorPos=function(a,b)cx,cy=a,b end
 s.getSize=function()return w,h end
 s.write=function(v)
  v=tostring(v or"");if cy<1 or cy>h or cx>w then return end;v=v:sub(1,math.max(0,w-cx+1));local row=textRows[cy]or string.rep(" ",w);textRows[cy]=row:sub(1,cx-1)..v..row:sub(cx+#v)
  for i=0,#v-1 do s._bg[cy]=s._bg[cy]or{};s._bg[cy][cx+i]=bg end
  cx=cx+#v
 end
 s._bg={}
 s.output=function()local out={};for i=1,h do out[i]=textRows[i]or string.rep(" ",w)end;return table.concat(out,"\n")end
 s.greenShape=function()
  local rowsWith,maxWidth=0,0
  for yy,cells in pairs(s._bg)do local n=0;for _,c in pairs(cells)do if c==colors.lime then n=n+1 end end;if n>0 then rowsWith=rowsWith+1;if n>maxWidth then maxWidth=n end end end
  return rowsWith,maxWidth
 end
 return s
end
local main=surface(68,30);local powerMon=surface(25,30);local fleetMon=surface(25,30)
local devices={main={type="monitor",object=main},left={type="monitor",object=powerMon},right={type="monitor",object=fleetMon}}
peripheral={}
peripheral.getNames=function()return{"main","left","right"}end
peripheral.getType=function(n)return devices[n].type end
peripheral.hasType=function(n,t)return devices[n]and devices[n].type==t end
peripheral.wrap=function(n)return devices[n]and devices[n].object end
term={setBackgroundColor=function()end,setTextColor=function()end,clear=function()end,setCursorPos=function()end,write=function()end}
os.getComputerLabel=function()return"Main Base"end
os.time=function()return 20.0 end
package.loaded["clients.admin_v11"]=nil
package.loaded["clients.admin"]=nil
local admin=assert(loadfile("clients/admin.lua"))();admin.init({name="Main Base"})
local aenv={version="5.0.0-alpha.56",state={
 doors={doors={{name="FRONT GATE",open=true,online=true},{name="ROOM PANEL",open=false,online=true}}},
 power={stored=800,capacity=1000,input=32000,output=22000,filledPercentage=.8},
 attachments={sensors={{type="environment_detector",summary="RAINING"}}},
 fleet={[1]={name="MAIN BASE",online=true,version="5.0.0-alpha.56"},[2]={name="ROOM PANEL",online=true,version="5.0.0-alpha.56"},[3]={name="POCKET",online=true,version="5.0.0-alpha.56"}}
}}
assert(admin.render(aenv,{localServer=true})~=false,"admin render failed")
local center=main.output();local left=powerMon.output();local right=fleetMon.output()
assert(center:find("COMMAND CENTER",1,true),"center title missing")
assert(center:find("FRONT GATE",1,true) and center:find("ROOM PANEL",1,true),"center does not show door names")
assert(center:find("OPEN",1,true) and center:find("CLOSED",1,true),"center does not show door open/closed states")
assert(not center:find("VERSION ",1,true),"version still duplicated on center")
assert(not center:find("STORED ",1,true) and not center:find("FE/t",1,true),"power telemetry still duplicated on center")
assert(left:find("POWER",1,true),"dedicated power monitor missing")
local greenRows,greenWidth=powerMon.greenShape();assert(greenRows>=6 and greenWidth>=8,"power battery is not wide/vertical enough")
assert(right:find("FLEET",1,true) and right:find("VERSION",1,true),"fleet/version not moved to right monitor")
realPrint("alpha56 tablet/admin smoke test OK")
