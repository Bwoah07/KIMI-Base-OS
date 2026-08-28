package.path="./?.lua;./?/init.lua;"..package.path

local realPrint=print
colors={black=1,white=2,lightGray=3,lime=4,orange=5,red=6,gray=7,cyan=8,lightBlue=9,yellow=10,blue=11}
local now=123456
local function mon(w,h)
 local cells={};local cx,cy=1,1;local m={}
 function m.setTextScale()end
 function m.getSize()return w,h end
 function m.setBackgroundColor()end
 function m.setTextColor()end
 function m.clear()cells={}end
 function m.setCursorPos(x,y)cx,cy=x,y end
 function m.write(s)cells[cy]=cells[cy]or{};cells[cy][cx]=tostring(s)end
 function m.output()local out={};for y=1,h do local row=cells[y]or{};local parts={};for _,s in pairs(row)do parts[#parts+1]=s end;out[#out+1]=table.concat(parts," ")end;return table.concat(out,"\n")end
 return m
end
local main,power,fleet,weather,s1,s2,s3=mon(60,25),mon(50,20),mon(40,20),mon(40,20),mon(40,20),mon(40,20),mon(40,20)
local devices={main=main,power=power,fleet=fleet,weather=weather,s1=s1,s2=s2,s3=s3}
peripheral={getNames=function()return{"main","power","fleet","weather","s1","s2","s3"}end,getType=function(n)return devices[n]and"monitor"or nil end,hasType=function(n,t)return devices[n]~=nil and t=="monitor"end,wrap=function(n)return devices[n]end}
os={epoch=function()return now end,time=function()return 9.5 end,getComputerLabel=function()return"MAIN BASE"end,getComputerID=function()return 7 end}
term={setBackgroundColor=function()end,setTextColor=function()end,clear=function()end,setCursorPos=function()end,write=function()end}
keys={left=203,right=205,one=2,two=3,three=4,four=5,five=6,six=7,seven=8,eight=9,nine=10}

package.loaded["clients.admin_v12"]={init=function()return true end,render=function()return true end,handleEvent=function()return false end}
for _,name in ipairs({"clients.admin_v13","clients.admin_v14","clients.admin_v15","clients.admin_v16","clients.admin_v17","clients.admin_v18","clients.admin_v19","clients.admin_v20","clients.admin_v21","clients.admin_v22","clients.admin_v23","clients.admin_v24","clients.admin_v25","clients.admin_v26","clients.admin_v27","clients.admin_v28","clients.admin_v29"})do package.loaded[name]=nil end
local admin=require("clients.admin_v29")
admin.init({name="MAIN BASE"})
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
assert(called.module==nil,"OFFLINE fleet row was incorrectly treated as reachable or deleted on first tap")
assert(fleet.output():find("OFFLINE",1,true)and fleet.output():find("AGAIN TO FORGET",1,true),"offline fleet touch did not preserve reachability truth + two-tap cleanup")
realPrint("alpha73 base nervous system smoke test OK")