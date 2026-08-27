local M={id="builder"}

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
local function call(name,method)
 local ok,v=pcall(peripheral.call,name,method);if ok and v~=nil then return v,true end
end
local function first(name,set,list)
 for _,m in ipairs(list)do if set[m]then local v,ok=call(name,m);if ok then return v,m end end end
end
local function num(v)if type(v)=="number"then return v end;return tonumber(v)end
local function bool(v)if type(v)=="boolean"then return v end;if type(v)=="number"then return v~=0 end;local s=tostring(v or""):lower();if s=="true"or s=="running"or s=="active"or s=="working"then return true end;if s=="false"or s=="idle"or s=="stopped"then return false end end
local function isBuilder(name,ts,set)
 local text=norm(name)..norm(table.concat(ts," "))
 if text:find("builder",1,true)or text:find("quarry",1,true)then return true end
 local progress=(set.getProgress or set.getProgressPercent or set.getProgressPercentage or set.getProcessedBlocks or set.getRemainingBlocks)
 local work=(set.isRunning or set.isActive or set.getStatus or set.getCurrentLevel or set.getCurrentY)
 return progress and work or false
end
local function oldFor(previous,name)
 for _,b in ipairs(previous and previous.builders or{})do if tostring(b.peripheral)==tostring(name)then return b end end
end
local function pct(v)
 v=num(v);if not v then return nil end;if v>=0 and v<=1 then v=v*100 end;return math.max(0,math.min(100,v))
end
local function deriveRate(now,b,old)
 if not old then return end
 local dt=(now-(tonumber(old.sampledAt)or now))/1000;if dt<=0 then return end
 if b.processed and old.processed and b.processed>=old.processed then
  local d=b.processed-old.processed;if d>0 then b.rate=d/dt end
 end
 if not b.rate and b.progress and old.progress and b.progress>=old.progress then
  local d=b.progress-old.progress;if d>0 then b.percentRate=d/dt end
 end
 if b.remaining and b.rate and b.rate>0 then b.etaSeconds=b.remaining/b.rate
 elseif b.progress and b.percentRate and b.percentRate>0 and b.progress<100 then b.etaSeconds=(100-b.progress)/b.percentRate end
end

function M.read(previous)
 local now=os.epoch("utc");local out={builders={},count=0,_status="offline",_updated=now}
 local names=peripheral.getNames();table.sort(names)
 for _,name in ipairs(names)do
  local ml,set=methods(name);local ts=types(name)
  if isBuilder(name,ts,set)then
   local b={peripheral=name,type=ts[1],types=ts,methods=ml,methodCount=#ml,sampledAt=now}
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
   v=first(name,set,{"getMinY","getMinimumY"});b.minY=num(v)
   v=first(name,set,{"getMaxY","getMaximumY"});b.maxY=num(v)
   v=first(name,set,{"getEnergy","getStoredEnergy","getEnergyStored"});b.energy=num(v)
   v=first(name,set,{"getEnergyCapacity","getMaxEnergy","getMaxEnergyStored"});b.energyCapacity=num(v)
   v=first(name,set,{"getEnergyUsage","getPowerUsage","getRfPerTick","getFEPerTick"});b.energyUsage=num(v)
   deriveRate(now,b,oldFor(previous,name))
   b.apiLimited=not(b.progress or b.processed or b.remaining or b.currentY)
   out.builders[#out.builders+1]=b
  end
 end
 out.count=#out.builders;out._status=out.count>0 and"online"or"offline"
 return out
end

return M
