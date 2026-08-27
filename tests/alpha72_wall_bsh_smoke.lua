local realPrint=print
colors={white=1,orange=2,lightBlue=8,lime=32,gray=128,lightGray=256,cyan=512,blue=2048,red=16384,black=32768}
keys={left=203,right=205,one=2,two=3,three=4,four=5,five=6,six=7,seven=8,eight=9,nine=10}

local function surface(w,h)
 local rows,x,y={},1,1
 local s={}
 s.setTextScale=function()end;s.setTextColor=function()end;s.setBackgroundColor=function()end
 s.clear=function()rows={};x,y=1,1 end
 s.setCursorPos=function(a,b)x,y=a,b end
 s.getSize=function()return w,h end
 s.write=function(v)v=tostring(v or"");if y<1 or y>h or x>w then return end;v=v:sub(1,math.max(0,w-x+1));local row=rows[y]or string.rep(" ",w);rows[y]=row:sub(1,x-1)..v..row:sub(x+#v);x=x+#v end
 s.output=function()local out={};for i=1,h do out[i]=rows[i]or string.rep(" ",w)end;return table.concat(out,"\n")end
 return s
end

-- Match the photographed 7-monitor wall: center, wide power, wide fleet,
-- wide environment, then three tall dedicated sensor panels.
local main=surface(68,30)
local power=surface(60,20)
local fleet=surface(58,20)
local envMon=surface(50,20)
local s1=surface(25,30)
local s2=surface(25,29)
local s3=surface(25,28)
local devices={
 main={type="monitor",object=main},power={type="monitor",object=power},fleet={type="monitor",object=fleet},
 env={type="monitor",object=envMon},s1={type="monitor",object=s1},s2={type="monitor",object=s2},s3={type="monitor",object=s3},
}
peripheral={}
peripheral.getNames=function()return{"main","power","fleet","env","s1","s2","s3"}end
peripheral.getType=function(n)return devices[n]and devices[n].type end
peripheral.hasType=function(n,t)return devices[n]and devices[n].type==t end
peripheral.wrap=function(n)return devices[n]and devices[n].object end
term={setBackgroundColor=function()end,setTextColor=function()end,clear=function()end,setCursorPos=function()end,write=function()end}
os={getComputerLabel=function()return"KIMI-7"end,getComputerID=function()return 7 end,time=function()return 8.25 end,epoch=function()return 123456 end}

for _,m in ipairs({"clients.admin_v12","clients.admin_v13","clients.admin_v14","clients.admin_v15","clients.admin_v16","clients.admin_v17","clients.admin_v18","clients.admin"})do package.loaded[m]=nil end
local admin=assert(loadfile("clients/admin.lua"))();admin.init({name="Main Base"})
local sensors={
 {name="environment_detector",reportedName="ENVIRONMENT DETECTOR",type="environment_detector",summary="TERRALITH:HIGHLANDS / OVERWORLD",categories={"sensor"},_source="42",metrics={temperature=18,humidity=62}},
 {name="geo_scanner",reportedName="GEO SCANNER",type="geo_scanner",summary="ONLINE",categories={"sensor_candidate"},_source="42",metrics={entityCount=12}},
 {name="player_detector",reportedName="PLAYER DETECTOR",type="player_detector",summary="1 PLAYER(S) ONLINE",categories={"sensor"},_source="42",metrics={onlinePlayers=1}},
}
local env={version="5.0.0-alpha.72",state={
 doors={doors={{name="ROOM PANEL",open=false,online=true}}},
 environment={online=true,weather="SUNNY",biome="terralith:highlands",dimension="overworld",moon="waxing_crescent",blockLight=12,skyLight=15},
 attachments={devices=sensors,sensors={sensors[1],sensors[3]}},
 power={matrices={{peripheral="inductionPort_1",stored=1000,capacity=1000,input=200,output=200,net=0,filledPercentage=1}},fluxNetworks={{networkName="BASE FLUX",stored=5000,net=100},{networkName="BACKUP FLUX",stored=2500,net=-50}}},
 power_reserve={status="NO RESERVE MATRIX",matrixCount=1,mainPeripheral="inductionPort_1",mainPercent=100,lowPercent=20,highPercent=80,configured=false,feeding=false},
 fleet={[1]={name="MAIN",online=true,version="5.0.0-alpha.72"}},
}}
assert(admin.render(env,{localServer=true})~=false,"alpha72 admin render failed")

local center=main.output();local p=power.output();local f=fleet.output();local ee=envMon.output();local a,b,c=s1.output(),s2.output(),s3.output()
assert(center:find("COMMAND CENTER",1,true),"main command center disappeared")
assert(not center:find("ROOM PANEL",1,true),"HOME regained door names")
assert(p:find("MAIN MATRIX",1,true)and p:find("100.0%",1,true),"wide POWER lost main Matrix")
assert(p:find("RESERVE",1,true)and p:find("NOT INSTALLED",1,true),"wide POWER did not translate one-Matrix reserve state")
assert(p:find("FLUX NETWORKS",1,true)and p:find("BASE FLUX",1,true)and p:find("BACKUP FLUX",1,true),"wide POWER lost Flux networks")
assert(f:find("FLEET",1,true),"fleet monitor was overwritten")
assert(ee:find("ENVIRONMENT",1,true)and ee:find("SUNNY",1,true)and ee:find("HIGHLANDS",1,true),"wide spare monitor did not become environment dashboard")
assert(a:find("ENVIRONMENT DETECTOR",1,true),"sensor panel 1 did not get first unique sensor")
assert(b:find("GEO SCANNER",1,true),"sensor candidate was not assigned to a dedicated panel")
assert(c:find("PLAYER DETECTOR",1,true)and c:find("1 PLAYER",1,true),"sensor panel 3 did not get player detector")
assert(not a:find("GEO SCANNER",1,true)and not b:find("PLAYER DETECTOR",1,true),"sensor panels are still cloned lists")

-- Reserve telemetry from a KIMI computer with no Matrix must advertise OFFLINE,
-- so canonical state prefers the room that actually owns the battery.
package.loaded["core.power_reserve"]=nil;package.loaded["modules.power_reserve"]=nil
fs={exists=function()return false end,isDir=function()return false end,makeDir=function()end,open=function()return nil end}
textutils={unserialize=function()return nil end,serialize=function()return"{}"end}
peripheral.getMethods=function()return{}end
peripheral.call=function()return nil end
peripheral.getNames=function()return{}end
local pr=assert(loadfile("modules/power_reserve.lua"))()
local none=pr.read();assert(none.matrixCount==0 and none._status=="offline"and none.online==false,"matrix-less KIMI still advertises healthy reserve telemetry")

local methods={getEnergy=true,getMaxEnergy=true,getLastInput=true,getLastOutput=true,getTransferCap=true,getEnergyFilledPercentage=true}
peripheral.getNames=function()return{"inductionPort_1"}end
peripheral.getMethods=function()local out={};for k in pairs(methods)do out[#out+1]=k end;return out end
peripheral.call=function(_,method)if method=="getEnergy"then return 500 elseif method=="getMaxEnergy"then return 1000 elseif method=="getLastInput"then return 20 elseif method=="getLastOutput"then return 10 elseif method=="getTransferCap"then return 999 elseif method=="getEnergyFilledPercentage"then return .5 end end
local one=pr.read();assert(one.matrixCount==1 and one._status=="online"and one.online==true,"real Matrix owner did not advertise healthy reserve telemetry")
assert(one.main and one.main.peripheral=="inductionPort_1","single Matrix was not identified as MAIN")
realPrint("alpha72 wall BSH smoke test OK")
