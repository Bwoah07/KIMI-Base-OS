local realPrint=print
local function read(path)local f=assert(io.open(path,"r"));local s=f:read("*a");f:close();return s end

-- Builder learns real work rate and ETA from successive samples.
local now=10000;local processed=250;local progress=25
os={epoch=function()return now end}
local methodList={"isRunning","getProgress","getProcessedBlocks","getTotalBlocks","getEnergy","getEnergyCapacity"}
peripheral={getNames=function()return{"rftoolsbuilder:builder_0"}end,getType=function()return"rftools_builder"end,getMethods=function()return methodList end}
peripheral.call=function(_,m)if m=="isRunning"then return true elseif m=="getProgress"then return progress elseif m=="getProcessedBlocks"then return processed elseif m=="getTotalBlocks"then return 1000 elseif m=="getEnergy"then return 500000 elseif m=="getEnergyCapacity"then return 1000000 end end
package.loaded["modules.builder"]=nil
local bm=assert(loadfile("modules/builder.lua"))();local first=bm.read();assert(first.count==1 and first.builders[1].progress==25,"Builder was not discovered")
now=20000;processed=350;progress=35;local second=bm.read(first);local b=second.builders[1]
assert(math.abs((b.rate or 0)-10)<.001,"Builder work rate was not learned")
assert(b.remaining==650 and math.abs((b.etaSeconds or 0)-65)<.001,"Builder ETA was not derived from real progress")

-- Live update contract: transactional updater, program handoff, no normal reboot.
local us=read("core/update_service.lua");local km=read("kimi.lua");local st=read("startup.lua");local wd=read("core/watchdog.lua")
assert(us:find("live updating",1,true)and us:find('shell.run("updater", "auto")',1,true),"live updater does not install in-process")
assert(us:find("__KIMI_LIVE_RELOAD__",1,true)and st:find("reload_requested",1,true)and wd:find("__KIMI_LIVE_RELOAD__",1,true),"live reload handoff is incomplete")
assert(not us:find("os.reboot()",1,true)and not km:find("os.reboot()",1,true),"normal KIMI update path still hard-reboots")
local serverSource=read("roles/server.lua")
assert(serverSource:find('require("core.fleet_health")',1,true)and serverSource:find("fleetHealth.reachability",1,true),"server is not using shared fleet reachability truth")
assert(serverSource:find('"fleet.identify"',1,true),"fleet identify transport missing")
assert(serverSource:find("aggregateBuilders",1,true),"Builder telemetry is not aggregated across KIMI nodes")
assert(read("roles/client_v4.lua"):find('"door.command.direct"',1,true),"alpha70 direct Pocket door transport disappeared")

-- Seven-screen Command Center: Power, Fleet, Environment animation, AE2,
-- Builder, and a rotating sensor screen all receive useful content.
colors={white=1,orange=2,lightBlue=8,lime=32,gray=128,lightGray=256,cyan=512,blue=2048,yellow=16,red=16384,black=32768}
keys={left=203,right=205,one=2,two=3,three=4,four=5,five=6,six=7,seven=8,eight=9,nine=10}
local function surface(w,h)
 local rows,x,y={},1,1;local s={}
 s.setTextScale=function()end;s.setTextColor=function()end;s.setBackgroundColor=function()end;s.clear=function()rows={};x,y=1,1 end;s.setCursorPos=function(a,b)x,y=a,b end;s.getSize=function()return w,h end
 s.write=function(v)v=tostring(v or"");if y<1 or y>h or x>w then return end;v=v:sub(1,math.max(0,w-x+1));local row=rows[y]or string.rep(" ",w);rows[y]=row:sub(1,x-1)..v..row:sub(x+#v);x=x+#v end
 s.output=function()local out={};for i=1,h do out[i]=rows[i]or string.rep(" ",w)end;return table.concat(out,"\n")end;return s
end
local main,power,fleet,weather=surface(68,30),surface(60,20),surface(58,20),surface(50,20)
local s1,s2,s3=surface(25,30),surface(25,29),surface(25,28)
local devices={main={type="monitor",object=main},power={type="monitor",object=power},fleet={type="monitor",object=fleet},weather={type="monitor",object=weather},s1={type="monitor",object=s1},s2={type="monitor",object=s2},s3={type="monitor",object=s3}}
peripheral={getNames=function()return{"main","power","fleet","weather","s1","s2","s3"}end,getType=function(n)return devices[n]and devices[n].type end,hasType=function(n,t)return devices[n]and devices[n].type==t end,wrap=function(n)return devices[n]and devices[n].object end}
term={setBackgroundColor=function()end,setTextColor=function()end,clear=function()end,setCursorPos=function()end,write=function()end}
local timerSeq=0;os={getComputerLabel=function()return"MAIN BASE"end,getComputerID=function()return 7 end,time=function()return 8.25 end,epoch=function()return 123456 end,startTimer=function()timerSeq=timerSeq+1;return timerSeq end,cancelTimer=function()end}
for _,m in ipairs({"clients.admin_v12","clients.admin_v13","clients.admin_v14","clients.admin_v15","clients.admin_v16","clients.admin_v17","clients.admin_v18","clients.admin_v19","clients.admin_v20","clients.admin_v21","clients.admin_v22","clients.admin_v23","clients.admin_v24","clients.admin_v25","clients.admin_v26","clients.admin_v27","clients.admin_v28","clients.admin_v29","clients.admin_v30","clients.admin"})do package.loaded[m]=nil end
local admin=assert(loadfile("clients/admin.lua"))();admin.init({name="Main Base"})
local sens={
 {name="environment_detector",reportedName="ENVIRONMENT DETECTOR",type="environment_detector",summary="SUNNY",categories={"sensor"},_source="42",metrics={temperature=18}},
 {name="geo_scanner",reportedName="GEO SCANNER",type="geo_scanner",summary="ONLINE",categories={"sensor_candidate"},_source="42",metrics={entityCount=12}},
 {name="player_detector",reportedName="PLAYER DETECTOR",type="player_detector",summary="1 PLAYER",categories={"sensor"},_source="42",metrics={onlinePlayers=1}},
}
local env={serverId=7,version="5.0.0-alpha.81",state={
 doors={doors={{name="ROOM PANEL",open=false,online=true}}},environment={online=true,weather="SUNNY",biome="terralith:highlands",dimension="overworld",moon="waxing_crescent",blockLight=12,skyLight=15},
 attachments={devices=sens,sensors=sens},power={matrices={{stored=1000,capacity=1000,input=200,output=200,filledPercentage=1}},fluxNetworks={{networkName="BASE FLUX",stored=5000,net=100}}},power_reserve={status="NO RESERVE MATRIX"},
 ae2={bridge="meBridge_0",online=true,_status="online",itemCount=123456,itemTypes=321,usedItemStorage=100,totalItemStorage=1000,storedEnergy=5000,energyCapacity=10000,energyUsage=12,avgPowerInjection=15,craftingJobs=2},
 builder={builders={{peripheral="rftoolsbuilder:builder_0",_source="55",running=true,progress=35,processed=350,total=1000,remaining=650,rate=10,etaSeconds=65,energy=500000,energyCapacity=1000000}}},
 fleet={[7]={name="MAIN BASE",role="server",lastSeen=123456,ageMs=0,version="5.0.0-alpha.81"},[42]={name="MYSTERY ROOM",role="client",lastSeen=103456,ageMs=20000,version="5.0.0-alpha.81"}}
}}
assert(admin.render(env,{localServer=true})~=false,"alpha73 admin render failed")
local outs={main.output(),power.output(),fleet.output(),weather.output(),s1.output(),s2.output(),s3.output()};for i,v in ipairs(outs)do assert(v:match("%S"),"monitor "..i.." was left unused")end
assert(power.output():find("MAIN MATRIX",1,true)and power.output():find("BASE FLUX",1,true),"POWER monitor lost Matrix/Flux")
assert(fleet.output():find("FLEET / IDENTIFY",1,true)and fleet.output():find("OFFLINE",1,true),"FLEET monitor lacks truthful offline state")
assert(weather.output():find("ENVIRONMENT / WEATHER",1,true)and weather.output():find("-- O --",1,true),"sun animation/weather dashboard missing")
local extras=s1.output().."\n"..s2.output().."\n"..s3.output();assert(extras:find("AE2 NETWORK",1,true),"AE2 did not get a monitor");assert(extras:find("BUILDER / QUARRY",1,true)and extras:find("ETA 1m 05s",1,true),"Builder dashboard/ETA missing");assert(extras:find("SENSOR",1,true),"remaining monitor was not used for sensors")
local called={};admin.handleEvent({"monitor_touch","fleet",5,13},env,function(module,action,args)called={module=module,action=action,args=args};return{ok=true}end)
assert(called.module==nil,"OFFLINE fleet row was incorrectly treated as reachable for identify")
assert(fleet.output():find("OFFLINE",1,true)and fleet.output():find("LAST SEEN",1,true),"offline identify touch did not explain reachability state")
realPrint("alpha73 base nervous system smoke test OK")
