local M={id="builder"}
local RFT_MODE={[0]="COPY",[1]="MOVE",[2]="SWAP",[3]="BACK",[4]="COLLECT"}

local function norm(v)return tostring(v or""):lower():gsub("[^a-z0-9]","")end
local function methods(name)
 local ok,list=pcall(peripheral.getMethods,name);local out,set={},{}
 if ok and type(list)=="table"then for _,m in ipairs(list)do if type(m)=="string"and not set[m]then set[m]=true;out[#out+1]=m end end end
 table.sort(out);return out,set
end
local function types(name)
 local r={pcall(peripheral.getType,name)};if not r[1]then return{"unknown"}end;table.remove(r,1)
 local out,seen={},{};for _,v in ipairs(r)do if type(v)=="string"and not seen[v]then seen[v]=true;out[#out+1]=v end end
 if #out==0 then out[1]="unknown"end;return out
end
local function call(name,method,...)
 local ok,v=pcall(peripheral.call,name,method,...);if ok and v~=nil then return v,true end
end
local function first(name,set,list)
 for _,m in ipairs(list)do if set[m]then local v,ok=call(name,m);if ok then return v,m end end end
end
local function num(v)if type(v)=="number"then return v end;return tonumber(v)end
local function bool(v)
 if type(v)=="boolean"then return v end;if type(v)=="number"then return v~=0 end
 local s=tostring(v or""):lower();if s=="true"or s=="running"or s=="active"or s=="working"then return true end
 if s=="false"or s=="idle"or s=="stopped"then return false end
end
local function pct(v)
 v=num(v);if not v then return nil end;if v>=0 and v<=1 then v=v*100 end;return math.max(0,math.min(100,v))
end
local function isBuilder(name,ts,set)
 local text=norm(name)..norm(table.concat(ts," "))
 if text:find("builder",1,true)or text:find("quarry",1,true)then return true end
 local progress=(set.getProgress or set.getProgressPercent or set.getProgressPercentage or set.getProcessedBlocks or set.getRemainingBlocks)
 local work=(set.isRunning or set.isActive or set.getStatus or set.getCurrentLevel or set.getCurrentY)
 return progress and work or false
end
local function isBlockReader(ts,set)
 local text=norm(table.concat(ts," "))
 return text:find("blockreader",1,true)~=nil or(set.getBlockName and set.getBlockData)
end
local function oldFor(previous,name)
 for _,b in ipairs(previous and previous.builders or{})do if tostring(b.peripheral)==tostring(name)then return b end end
end
local function deriveRate(now,b,old)
 if not old then return end
 local dt=(now-(tonumber(old.sampledAt)or now))/1000;if dt<=0 then return end
 if b.processed and old.processed and b.processed>=old.processed then local d=b.processed-old.processed;if d>0 then b.rate=d/dt end end
 if not b.rate and b.progress and old.progress and b.progress>=old.progress then local d=b.progress-old.progress;if d>0 then b.percentRate=d/dt end end
 if b.remaining and b.rate and b.rate>0 then b.etaSeconds=b.remaining/b.rate
 elseif b.progress and b.percentRate and b.percentRate>0 and b.progress<100 then b.etaSeconds=(100-b.progress)/b.percentRate end
end

local function flatten(root)
 local out,details,count={}, {},0
 local function walk(v,path,keyPath,depth)
  if count>=384 or depth>5 then return end
  if type(v)=="table"then
   for k,x in pairs(v)do
    local label=tostring(k);local shown=path==""and label or(path.."."..label)
    walk(x,shown,keyPath..norm(k),depth+1)
   end
  elseif type(v)=="number"or type(v)=="boolean"or type(v)=="string"then
   if keyPath~=""then out[keyPath]=v;details[#details+1]={path=path,value=tostring(v)};count=count+1 end
  end
 end
 walk(root,"","",0);table.sort(details,function(a,b)return a.path<b.path end);return out,count,details
end
local function pick(flat,exact,contains)
 for _,k in ipairs(exact or{})do if flat[k]~=nil then return flat[k],k end end
 for k,v in pairs(flat)do for _,needle in ipairs(contains or{})do if k:find(needle,1,true)then return v,k end end end
end
local function pickNum(flat,exact,contains)local v,k=pick(flat,exact,contains);return num(v),k end
local function pickBool(flat,exact,contains)local v,k=pick(flat,exact,contains);return bool(v),k end

local function enrichFromFlat(b,flat)
 local v,k
 v,k=pickNum(flat,{"progresspercent","progresspercentage","progress","percentage","percent"},{"progresspercent","progresspercentage"});b.progress=pct(v);b.progressField=k
 v,k=pickNum(flat,{"processedblocks","blocksprocessed","processed","completed","done"},{"processedblocks","blocksprocessed"});b.processed=v;b.processedField=k
 v,k=pickNum(flat,{"totalblocks","blockstotal","total","worktotal"},{"totalblocks","blockstotal"});b.total=v;b.totalField=k
 v,k=pickNum(flat,{"remainingblocks","blocksremaining","remaining","workremaining"},{"remainingblocks","blocksremaining"});b.remaining=v;b.remainingField=k
 v,k=pickNum(flat,{"scany","currenty","currentlevel","scanposy"},{"scany","currenty","currentlevel"});b.currentY=v;b.positionField=k
 v=pickNum(flat,{"scanx","currentx","scanposx"},{"scanx","currentx"});b.currentX=v
 v=pickNum(flat,{"scanz","currentz","scanposz"},{"scanz","currentz"});b.currentZ=v
 v=pickNum(flat,{"minboxy","miny","boxminy"},{"minboxy","boxminy"});b.minY=v
 v=pickNum(flat,{"maxboxy","maxy","boxmaxy"},{"maxboxy","boxmaxy"});b.maxY=v
 v=pickNum(flat,{"minboxx","minx","boxminx"},{"minboxx","boxminx"});b.minX=v
 v=pickNum(flat,{"maxboxx","maxx","boxmaxx"},{"maxboxx","boxmaxx"});b.maxX=v
 v=pickNum(flat,{"minboxz","minz","boxminz"},{"minboxz","boxminz"});b.minZ=v
 v=pickNum(flat,{"maxboxz","maxz","boxmaxz"},{"maxboxz","boxmaxz"});b.maxZ=v
 v,k=pickNum(flat,{"energy","infoenergy","storedenergy","infostoredenergy","energystored","power"},{"storedenergy","energystored"});b.energy=v;b.energyField=k
 v,k=pickNum(flat,{"maxenergy","infomaxenergy","energycapacity","infoenergycapacity","maxenergystored"},{"maxenergy","energycapacity"});b.energyCapacity=v;b.energyCapacityField=k
 v=pickNum(flat,{"energyusage","powerusage","rfpertick","fepertick"},{"powerusage","rfpertick","fepertick"});b.energyUsage=v
 v,k=pickBool(flat,{"running","active","working","enabled"},{"running","isactive","isworking"});b.running=v;b.runningField=k
 local status=pick(flat,{"status","state","infostatus"},{"workstatus","builderstatus"});if status~=nil then b.status=tostring(status)end
 v,k=pick(flat,{"lasterror","infolasterror","error","errorstatus","suspendreason"},{"lasterror","errormessage","suspendreason"});if v~=nil and tostring(v)~=""then b.error=tostring(v);b.errorField=k end
 v,k=pickNum(flat,{"mode","infomode"},{"buildermode"});if v~=nil then b.modeId=v;b.mode=RFT_MODE[math.floor(v)]or("MODE "..tostring(v));b.modeField=k end
 v=pick(flat,{"cardname","shapecard","cardtype","itemname"},{"shapecard","cardtype"});if v~=nil then b.card=tostring(v)end
 v=pick(flat,{"rsmode","redstonemode"},{"redstonemode"});if v~=nil then b.redstoneMode=tostring(v)end
 if not b.remaining and b.total and b.processed then b.remaining=math.max(0,b.total-b.processed)end
 if not b.progress and b.total and b.total>0 and b.processed then b.progress=math.max(0,math.min(100,b.processed/b.total*100))end
 -- If the reader exposes a complete scan box and scan position, expose an approximate
 -- geometric completion. This is useful for RFTools even when it does not publish a
 -- formal percent field. Keep it separate so the UI can label it honestly.
 if not b.progress and b.currentX and b.currentY and b.currentZ and b.minX and b.maxX and b.minY and b.maxY and b.minZ and b.maxZ then
  local sx,sy,sz=b.maxX-b.minX+1,b.maxY-b.minY+1,b.maxZ-b.minZ+1
  if sx>0 and sy>0 and sz>0 then
   local ix=math.max(0,math.min(sx-1,b.currentX-b.minX));local iy=math.max(0,math.min(sy-1,b.currentY-b.minY));local iz=math.max(0,math.min(sz-1,b.currentZ-b.minZ))
   local ordinal=((iy*sz)+iz)*sx+ix;local total=sx*sy*sz
   b.approxProgress=math.max(0,math.min(100,ordinal/math.max(1,total-1)*100));b.progress=b.approxProgress;b.progressApprox=true
   b.total=b.total or total;b.processed=b.processed or ordinal;b.remaining=b.remaining or math.max(0,total-ordinal)
  end
 end
end

local function finalize(now,b,old)
 if b.energy and b.energyCapacity and b.energyCapacity>0 then b.energyPercent=math.max(0,math.min(100,b.energy/b.energyCapacity*100))end
 if b.minX and b.maxX then b.sizeX=math.abs(b.maxX-b.minX)+1 end
 if b.minY and b.maxY then b.sizeY=math.abs(b.maxY-b.minY)+1 end
 if b.minZ and b.maxZ then b.sizeZ=math.abs(b.maxZ-b.minZ)+1 end
 if b.sizeX and b.sizeY and b.sizeZ then b.volume=b.sizeX*b.sizeY*b.sizeZ end
 if b.currentX and b.currentY and b.currentZ then b.position=string.format("%d, %d, %d",b.currentX,b.currentY,b.currentZ)end
 if b.progressField then b.progressSource=b.progressApprox and"APPROX BOX SCAN"or("FIELD "..b.progressField)
 elseif b.progressApprox then b.progressSource="APPROX BOX SCAN"
 elseif b.processed and b.total then b.progressSource="BLOCK COUNTS"end
 deriveRate(now,b,old)
 local moved=false
 if old then
  moved=(b.processed and old.processed and b.processed~=old.processed)or(b.progress and old.progress and b.progress~=old.progress)or(b.position and old.position and b.position~=old.position)
 end
 b.lastProgressAt=moved and now or(tonumber(old and old.lastProgressAt)or tonumber(old and old.sampledAt)or now)
 if b.running==true and now-b.lastProgressAt>=30000 then b.stalled=true;b.stalledSeconds=math.floor((now-b.lastProgressAt)/1000)end
 if b.error and b.error~=""then b.status="ERROR"
 elseif b.stalled then b.status="STALLED"
 elseif b.running==true then b.status=b.status or"RUNNING"
 elseif b.running==false then b.status=b.status or"IDLE"
 else b.status=b.status or"CONNECTED"end
 if b.running==true and b.energy~=nil and b.energy<=0 then b.issue="NO POWER"elseif b.error then b.issue=b.error elseif b.stalled then b.issue="NO PROGRESS"end
 b.apiLimited=not(b.progress or b.processed or b.remaining or b.currentY or b.energy or b.error)
 return b
end

local function readDirect(name,ts,ml,set,now,previous)
 local b={peripheral=name,type=ts[1],types=ts,methods=ml,methodCount=#ml,sampledAt=now,source="direct"}
 local v,m
 v,m=first(name,set,{"isRunning","isActive","isWorking","getRunning"});b.running=bool(v);b.runningMethod=m
 v,m=first(name,set,{"getStatus","getWorkStatus","getState","getMode"});if v~=nil then b.status=tostring(v)end;b.statusMethod=m
 v,m=first(name,set,{"getProgressPercent","getProgressPercentage","getProgress","getPercentage","getPercent"});b.progress=pct(v);b.progressMethod=m
 v,m=first(name,set,{"getProcessedBlocks","getBlocksProcessed","getProcessed","getDone","getCompleted"});b.processed=num(v);b.processedMethod=m
 v,m=first(name,set,{"getTotalBlocks","getBlocksTotal","getTotal","getWorkTotal"});b.total=num(v);b.totalMethod=m
 v,m=first(name,set,{"getRemainingBlocks","getBlocksRemaining","getRemaining","getWorkRemaining"});b.remaining=num(v);b.remainingMethod=m
 if not b.remaining and b.total and b.processed then b.remaining=math.max(0,b.total-b.processed)end
 if not b.progress and b.total and b.total>0 and b.processed then b.progress=math.max(0,math.min(100,b.processed/b.total*100))end
 v,m=first(name,set,{"getCurrentY","getCurrentLevel","getLevel","getY"});b.currentY=num(v);b.positionMethod=m
 v=first(name,set,{"getMinY","getMinimumY"});b.minY=num(v);v=first(name,set,{"getMaxY","getMaximumY"});b.maxY=num(v)
 v=first(name,set,{"getEnergy","getStoredEnergy","getEnergyStored"});b.energy=num(v);v=first(name,set,{"getEnergyCapacity","getMaxEnergy","getMaxEnergyStored"});b.energyCapacity=num(v)
 v=first(name,set,{"getEnergyUsage","getPowerUsage","getRfPerTick","getFEPerTick"});b.energyUsage=num(v)
 return finalize(now,b,oldFor(previous,name))
end

local function readBlockReader(name,ts,ml,set,now,previous)
 local blockName=first(name,set,{"getBlockName"});if type(blockName)~="string"then return nil end
 local target=norm(blockName);if not(target:find("builder",1,true)or target:find("quarry",1,true))then return nil end
 local data=first(name,set,{"getBlockData"})
 local b={peripheral=name,type=ts[1],types=ts,methods=ml,methodCount=#ml,sampledAt=now,source="block_reader",reader=true,targetBlock=blockName}
 if set.hasBlockEntity then local has=first(name,set,{"hasBlockEntity"});b.hasBlockEntity=bool(has)end
 if set.getBlockState then local blockState=first(name,set,{"getBlockState"});if type(blockState)=="table"then b.blockState=blockState end end
 if type(data)=="table"then
  local flat,count,details=flatten(data);b.rawFieldCount=count;b.rawFields={}
  for i=1,math.min(24,#details)do b.rawFields[i]=details[i]end
  enrichFromFlat(b,flat)
 else b.rawFieldCount=0 end
 return finalize(now,b,oldFor(previous,name))
end

function M.read(previous)
 local now=os.epoch("utc");local out={builders={},count=0,_status="offline",_updated=now}
 local names=peripheral.getNames();table.sort(names)
 for _,name in ipairs(names)do
  local ml,set=methods(name);local ts=types(name);local b
  if isBuilder(name,ts,set)then b=readDirect(name,ts,ml,set,now,previous)
  elseif isBlockReader(ts,set)then b=readBlockReader(name,ts,ml,set,now,previous)end
  if b then out.builders[#out.builders+1]=b end
 end
 out.count=#out.builders;out._status=out.count>0 and"online"or"offline"
 return out
end

return M
