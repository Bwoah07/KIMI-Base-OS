local realPrint=print
local realOs=os
local realPeripheral=peripheral
local realTerm=term
local realFs=fs
local realTextutils=textutils

colors={white=1,orange=2,lightBlue=8,lime=32,gray=128,lightGray=256,cyan=512,blue=2048,red=16384,black=32768}

local function surface(w,h)
 local rows,x,y,bg={},1,1,colors.black;local s={}
 s.setTextScale=function()end;s.setBackgroundColor=function(v)bg=v end;s.setTextColor=function()end
 s.clear=function()rows={};x,y=1,1 end;s.setCursorPos=function(a,b)x,y=a,b end;s.getSize=function()return w,h end
 s.write=function(v)v=tostring(v or"");if y<1 or y>h or x>w then return end;v=v:sub(1,math.max(0,w-x+1));local row=rows[y]or string.rep(" ",w);rows[y]=row:sub(1,x-1)..v..row:sub(x+#v);x=x+#v end
 s.output=function()local out={};for i=1,h do out[i]=rows[i]or string.rep(" ",w)end;return table.concat(out,"\n")end
 return s
end

-- -------------------------------------------------------------------------
-- 1) Command Center: HOME has no door UI, environment is prominent, SENSORS
--    includes candidates, and the dedicated power screen restores Flux + reserve.
-- -------------------------------------------------------------------------
local main=surface(68,30);local powerMon=surface(25,30);local fleetMon=surface(25,30)
local devices={main={type="monitor",object=main},left={type="monitor",object=powerMon},right={type="monitor",object=fleetMon}}
peripheral={
 getNames=function()return{"main","left","right"}end,
 getType=function(n)return devices[n]and devices[n].type end,
 hasType=function(n,t)return devices[n]and devices[n].type==t end,
 wrap=function(n)return devices[n]and devices[n].object end,
}
term={setBackgroundColor=function()end,setTextColor=function()end,clear=function()end,setCursorPos=function()end,write=function()end}
os={time=function()return 22.08 end,epoch=function()return 1000 end,getComputerLabel=function()return"Main Base"end}
package.loaded["clients.admin_v16"]={init=function()return true end,render=function()return true end,handleEvent=function()return false end}
package.loaded["clients.admin_v17"]=nil
local admin=assert(loadfile("clients/admin_v17.lua"))();admin.init({name="Main Base"})
local env={version="5.0.0-alpha.71",state={
 doors={doors={{name="ROOM PANEL",open=false,online=true}}},
 environment={online=true,weather="SUNNY",biome="minecraft:plains",dimension="minecraft:overworld",moon="FULL MOON",blockLight=11,skyLight=15},
 attachments={devices={
  {name="environment_detector_0",type="environment_detector",categories={"sensor"},summary="Sunny",metrics={temperature=21.5,humidity=0.45,weatherSunny=true}},
  {name="mystery_scanner_0",type="quantum_observer",categories={"sensor_candidate","data"},summary="Online",metrics={radiationRaw=7,entityCount=3}},
 },sensors={}},
 power={matrices={{peripheral="inductionPort_main",stored=800,capacity=1000,input=50,output=20,filledPercentage=.8}},fluxNetworks={{networkName="BANZA GRID",stored=9000,capacity=10000,input=400,output=300,net=100}}},
 power_reserve={mainPeripheral="inductionPort_main",reservePeripheral="inductionPort_backup",mainPercent=80,reservePercent=95,configured=true,feeding=true,status="FEEDING MAIN"},
 fleet={}
}}
assert(admin.render(env,{connected=true})~=false,"admin v17 render failed")
local home=main.output();local ptxt=powerMon.output()
assert(home:find("ENVIRONMENT",1,true)and home:find("SUNNY",1,true),"HOME lost weather/environment")
assert(home:find("SENSORS",1,true),"HOME lost sensor summary")
assert(not home:find("DOOR CONTROL",1,true)and not home:find("OPEN DOOR",1,true)and not home:find("ROOM PANEL",1,true),"door UI leaked onto HOME")
assert(ptxt:find("RESERVE",1,true)and ptxt:find("FEEDING MAIN",1,true),"power screen lost reserve status")
assert(ptxt:find("FLUX NETWORKS",1,true)and ptxt:find("BANZA GRID",1,true),"Flux network telemetry is missing")

-- Tap SENSORS tab (right third of bottom nav) and verify candidate sensor appears.
admin.handleEvent({"monitor_touch","main",58,29},env,function()return true end)
local stxt=main.output()
assert(stxt:find("DETECTED SENSORS 2",1,true),"sensor candidate was dropped")
assert(stxt:find("MYSTERY SCANNER 0",1,true)and stxt:find("RAD 7",1,true),"candidate sensor metrics not rendered")
assert(stxt:find("SUNNY",1,true)and stxt:find("PLAINS",1,true),"sensor page lost environment/weather")

-- -------------------------------------------------------------------------
-- 2) Wall client: fast lane excludes heavy modules, then Power/Reserve/AE2 come
--    back on the 5-second slow telemetry lane. This must not touch Pocket logic.
-- -------------------------------------------------------------------------
package.loaded["roles.client_v4"]=nil
package.loaded["core.network"]={send=function()return true end}
local scans={}
package.loaded["core.module_loader"]={readAll=function(modules,previous)
 local keys={};for k in pairs(modules or{})do keys[k]=true end;scans[#scans+1]=keys
 local out={};for k in pairs(modules or{})do out[k]={sample=true}end;return out
end}
local epoch=0
os={getComputerID=function()return 42 end,epoch=function()return epoch end,cancelTimer=function()end,startTimer=function()return 1 end,pullEvent=function()return"key",1 end}
package.loaded["roles.client_v3"]={run=function(cfg)
 local loader=package.loaded["core.module_loader"]
 local mods={doors={},environment={},attachments={},system={},power={},power_reserve={},ae2={}}
 local first=loader.readAll(mods,{power={cached=true},power_reserve={cached=true},ae2={cached=true}})
 assert(first.power and first.power.cached,"fast lane did not preserve cached power")
 epoch=5001
 local second=loader.readAll(mods,first)
 assert(second.power and second.power.sample,"slow lane did not refresh power")
 return true
end}
local client=assert(loadfile("roles/client_v4.lua"))()
assert(client.run({profile="wall",network={protocol="kimi-test"}})==true,"client_v4 wall run failed")
assert(scans[1].doors and scans[1].environment and scans[1].attachments and scans[1].system,"fast lane lost required room telemetry")
assert(not scans[1].power and not scans[1].ae2 and not scans[1].power_reserve,"heavy telemetry polluted fast lane")
local heavy=scans[#scans];assert(heavy.power and heavy.ae2 and heavy.power_reserve,"5-second heavy lane did not restore Power/Reserve/AE2")

-- -------------------------------------------------------------------------
-- 3) Reserve Matrix controller: configured gate feeds below 20%, then stands
--    down once MAIN reaches 80%+. No random peripheral selection is allowed.
-- -------------------------------------------------------------------------
package.loaded["core.power_reserve"]=nil
local gateSignals={}
peripheral={isPresent=function(name)return name=="reserve_gate"end,call=function(name,method,side,value)
 assert(name=="reserve_gate","reserve controller touched the wrong peripheral")
 if method=="setOutput"then gateSignals[#gateSignals+1]=value;return true end
 if method=="getOutput"then return gateSignals[#gateSignals]or false end
 error("unexpected method "..tostring(method),0)
end}
fs={exists=function()return false end,isDir=function()return false end}
textutils={}
local reserve=assert(loadfile("core/power_reserve.lua"))()
reserve.load=function()return{enabled=true,low=.20,high=.80,gate={target="reserve_gate",side="north",inverted=false}}end
local matrices={{peripheral="main",capacity=10000,stored=1000,filledPercentage=.10},{peripheral="backup",capacity=5000,stored=5000,filledPercentage=1}}
local rs=reserve.apply(matrices)
assert(rs.mainPeripheral=="main"and rs.reservePeripheral=="backup","reserve roles were not capacity-ranked")
assert(rs.feeding==true and rs.status=="FEEDING MAIN"and gateSignals[#gateSignals]==true,"reserve did not feed below low threshold")
matrices[1].stored=9000;matrices[1].filledPercentage=.90
rs=reserve.apply(matrices)
assert(rs.feeding==false and gateSignals[#gateSignals]==false,"reserve did not stand down above high threshold")

os=realOs;peripheral=realPeripheral;term=realTerm;fs=realFs;textutils=realTextutils
realPrint("alpha71 banger command-center smoke test OK")
