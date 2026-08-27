local realPrint=print
colors={white=1,orange=2,yellow=4,lightBlue=8,lime=32,gray=128,lightGray=256,cyan=512,blue=2048,red=16384,black=32768}
keys={left=203,right=205,one=2,two=3,three=4,four=5,five=6,six=7,seven=8,eight=9,nine=10}

-- Builder telemetry: Advanced Peripherals Block Reader aimed at an RFTools Builder.
local epoch=100000
local scan={0,10,0}
os={epoch=function()return epoch end,time=function()return 8.25 end,getComputerLabel=function()return"MAIN BASE"end,getComputerID=function()return 7 end}
peripheral={}
peripheral.getNames=function()return{"reader"}end
peripheral.getType=function()return"block_reader"end
peripheral.getMethods=function()return{"getBlockName","getBlockData"}end
peripheral.call=function(_,m)
 if m=="getBlockName"then return"rftoolsbuilder:builder"end
 if m=="getBlockData"then return{Info={scan=scan,minBox={0,0,0},maxBox={31,10,31},energy=500,maxEnergy=1000}}end
end
package.loaded["modules.builder"]=nil
local builder=assert(loadfile("modules/builder.lua"))()
local b1=builder.read(nil);assert(b1.online and b1.primary and b1.primary.source=="block_reader","Builder Block Reader was not detected")
assert(b1.primary.percent and b1.primary.percent<1,"Builder initial progress should start near zero")
epoch=102000;scan={0,9,0}
local b2=builder.read(b1);assert(b2.primary.percent and b2.primary.percent>b1.primary.percent,"Builder progress did not advance")
assert(b2.primary.etaSeconds and b2.primary.etaSeconds>0,"Builder ETA was not learned from live progress")
assert(b2.primary.energyPercent and math.floor(b2.primary.energyPercent+.5)==50,"Builder energy telemetry missing")

local function surface(w,h)
 local rows,x,y={},1,1;local s={}
 s.setTextScale=function()end;s.setTextColor=function()end;s.setBackgroundColor=function()end
 s.clear=function()rows={};x,y=1,1 end;s.setCursorPos=function(a,b)x,y=a,b end;s.getSize=function()return w,h end
 s.write=function(v)v=tostring(v or"");if y<1 or y>h or x>w then return end;v=v:sub(1,math.max(0,w-x+1));local row=rows[y]or string.rep(" ",w);rows[y]=row:sub(1,x-1)..v..row:sub(x+#v);x=x+#v end
 s.output=function()local o={};for i=1,h do o[i]=rows[i]or string.rep(" ",w)end;return table.concat(o,"\n")end
 return s
end
local main=surface(68,30);local power=surface(60,20);local fleet=surface(58,20);local weather=surface(50,20);local ae=surface(25,30);local quarry=surface(25,29);local sensor=surface(25,28)
local devices={main={type="monitor",object=main},power={type="monitor",object=power},fleet={type="monitor",object=fleet},weather={type="monitor",object=weather},ae={type="monitor",object=ae},quarry={type="monitor",object=quarry},sensor={type="monitor",object=sensor}}
peripheral.getNames=function()return{"main","power","fleet","weather","ae","quarry","sensor"}end
peripheral.getType=function(n)return devices[n]and devices[n].type end
peripheral.hasType=function(n,t)return devices[n]and devices[n].type==t end
peripheral.wrap=function(n)return devices[n]and devices[n].object end
term={setBackgroundColor=function()end,setTextColor=function()end,clear=function()end,setCursorPos=function()end,write=function()end}
epoch=200000
for _,m in ipairs({"clients.admin_v12","clients.admin_v13","clients.admin_v14","clients.admin_v15","clients.admin_v16","clients.admin_v17","clients.admin_v18","clients.admin_v19","clients.admin_v20","clients.admin_v21","clients.admin"})do package.loaded[m]=nil end
local admin=assert(loadfile("clients/admin.lua"))();admin.init({name="Main Base"})
local sensors={
 {name="environment_detector",reportedName="ENVIRONMENT DETECTOR",type="environment_detector",summary="SUNNY",categories={"sensor"},_source="42",metrics={temperature=18,humidity=60}},
 {name="geo_scanner",reportedName="GEO SCANNER",type="geo_scanner",summary="ONLINE",categories={"sensor_candidate"},_source="42",metrics={entityCount=12}},
 {name="player_detector",reportedName="PLAYER DETECTOR",type="player_detector",summary="1 PLAYER ONLINE",categories={"sensor"},_source="42",metrics={onlinePlayers=1}},
}
local env={serverId=7,version="5.0.0-alpha.73",state={
 doors={doors={{name="ROOM PANEL",open=false,online=true}}},
 environment={online=true,weather="SUNNY",biome="terralith:highlands",dimension="minecraft:overworld",moon="FULL MOON",blockLight=12,skyLight=15},
 attachments={devices=sensors,sensors=sensors},
 power={matrices={{stored=1000,capacity=1000,input=100,output=100,net=0,filledPercentage=1}},fluxNetworks={{networkName="BASE FLUX",stored=5000,net=100}}},
 power_reserve={status="NO RESERVE MATRIX",matrixCount=1,configured=false,feeding=false},
 ae2={bridge="me_bridge_0",online=true,connected=true,itemCount=123456,itemTypes=321,craftingJobs=2,storedEnergy=5000,energyCapacity=10000,energyUsage=50,avgPowerInjection=55,usedItemStorage=1000,totalItemStorage=2000},
 builder={online=true,primary={source="block_reader",status="RUNNING",active=true,percent=50,etaSeconds=120,chunk=2,chunks=4,yLevel=5,stored=500,energyPercent=50}},
 fleet={[7]={name="MAIN BASE",lastSeen=200000,online=true,version="5.0.0-alpha.73"},[42]={name="MYSTERY ROOM",lastSeen=180000,online=false,version="5.0.0-alpha.73"}},
}}
assert(admin.render(env,{localServer=true})~=false,"alpha73 admin render failed")
local wt=weather.output();local at=ae.output();local qt=quarry.output();local ft=fleet.output()
assert(wt:find("ENVIRONMENT // LIVE",1,true)and wt:find("SUNNY",1,true)and wt:find("OOO",1,true),"animated sunny environment screen missing")
assert(at:find("AE2 SYSTEM",1,true)and at:find("NETWORK ONLINE",1,true)and at:find("123.5K",1,true),"AE2 did not get a dedicated useful monitor")
assert(qt:find("QUARRY // BUILDER",1,true)and qt:find("50.0% COMPLETE",1,true)and qt:find("2m 00s",1,true),"Builder monitor lost progress/ETA")
assert(ft:find("MYSTERY ROOM",1,true)and ft:find("STALE",1,true),"Fleet did not use stable STALE state")
local called
local function action(module,cmd,args)called={module=module,cmd=cmd,args=args};return{ok=true}end
assert(admin.handleEvent({"monitor_touch","fleet",5,12},env,action)==true,"Fleet identify touch was not consumed")
assert(called and called.module=="system"and called.cmd=="identify"and tostring(called.args._source)=="42","Fleet identify targeted the wrong computer")

local k=assert(io.open("kimi.lua","r")):read("*a");assert(k:find("roles.server_v4",1,true),"kernel did not route Main Base through server_v4")
local sv=assert(io.open("roles/server_v4.lua","r")):read("*a");assert(sv:find("interval=60",1,true),"Main Base auto-update watch is not one minute")
local sys=assert(io.open("modules/system.lua","r")):read("*a");assert(sys:find("kimiIdentifyUntil",1,true)and sys:find("identify",1,true),"system identify command missing")
local wall=assert(io.open("clients/wall.lua","r")):read("*a");assert(wall:find("room_v18",1,true),"wall identify overlay not active")
local pocket=assert(io.open("roles/client_v4.lua","r")):read("*a");assert(pocket:find("door.command.direct",1,true)and pocket:find("RETRY_SECONDS=0.25",1,true),"alpha70 direct Pocket door path was disturbed")
realPrint("alpha73 EVERYTHING BSH smoke test OK")
