local M={id="builder"}

local function norm(v)return tostring(v or""):lower():gsub("[^a-z0-9]","")end
local function types(name)local r={pcall(peripheral.getType,name)};if not r[1]then return{}end;table.remove(r,1);return r end
local function methods(name)local ok,l=pcall(peripheral.getMethods,name);local s={};if ok and type(l)=="table"then for _,m in ipairs(l)do s[m]=true end end;return s end
local function call(name,method,...)
 local r={pcall(peripheral.call,name,method,...)};if not r[1]then return nil,false end;table.remove(r,1);return r,true
end
local function first(name,set,list)
 for _,m in ipairs(list)do if set[m]then local r,ok=call(name,m);if ok then return r and r[1],true,m end end end
 return nil,false,nil
end
local function pos(v,a,b,c)
 if type(v)=="table"then local x=tonumber(v.x or v.X or v[1]);local y=tonumber(v.y or v.Y or v[2]);local z=tonumber(v.z or v.Z or v[3]);if x and y and z then return{x=x,y=y,z=z}end end
 local x,y,z=tonumber(v),tonumber(a),tonumber(b);if x and y and z then return{x=x,y=y,z=z}end
end
local function keyfind(t,wanted,depth)
 if type(t)~="table"or(depth or 0)>8 then return nil end
 local n=norm(wanted)
 for k,v in pairs(t)do if norm(k)==n then return v end end
 for _,v in pairs(t)do if type(v)=="table"then local r=keyfind(v,wanted,(depth or 0)+1);if r~=nil then return r end end end
end
local function numberfind(t,names)
 for _,k in ipairs(names)do local v=keyfind(t,k);if tonumber(v)then return tonumber(v)end end
end
local function blockPos(t,name)return pos(keyfind(t,name))end
local function clamp(v,a,b)return math.max(a,math.min(b,v))end
local function progress(scan,minb,maxb)
 if not(scan and minb and maxb)then return nil end
 local minX,maxX=math.min(minb.x,maxb.x),math.max(minb.x,maxb.x);local minY,maxY=math.min(minb.y,maxb.y),math.max(minb.y,maxb.y);local minZ,maxZ=math.min(minb.z,maxb.z),math.max(minb.z,maxb.z)
 local levels=maxY-minY+1;if levels<=0 then return nil end
 local minCX,maxCX=math.floor(minX/16),math.floor(maxX/16);local minCZ,maxCZ=math.floor(minZ/16),math.floor(maxZ/16)
 local curCX=clamp(math.floor(scan.x/16),minCX,maxCX);local curCZ=clamp(math.floor(scan.z/16),minCZ,maxCZ)
 local chunksX=maxCX-minCX+1;local totalChunks=chunksX*(maxCZ-minCZ+1);local chunkIndex=(curCZ-minCZ)*chunksX+(curCX-minCX)
 local layer=clamp(maxY-scan.y,0,levels-1)
 local cx1,cx2=math.max(minX,curCX*16),math.min(maxX,curCX*16+15);local cz1,cz2=math.max(minZ,curCZ*16),math.min(maxZ,curCZ*16+15)
 local w,d=cx2-cx1+1,cz2-cz1+1;local within=0
 if w>0 and d>0 then within=((clamp(scan.z,cz1,cz2)-cz1)*w+(clamp(scan.x,cx1,cx2)-cx1))/math.max(1,w*d) end
 local p=(chunkIndex*levels+layer+within)/math.max(1,totalChunks*levels)
 return clamp(p,0,0.999999),chunkIndex+1,totalChunks,scan.y
end
local function scanDirect(name,set)
 if not set.getScan then return nil end
 local r,ok=call(name,"getScan");if not ok or not r then return nil end;return pos(r[1],r[2],r[3])
end
local function snapshotDirect(name,set)
 local scan=scanDirect(name,set);local stored=select(1,first(name,set,{"getEnergy","getEnergyStored","getStoredEnergy"}));local cap=select(1,first(name,set,{"getMaxEnergy","getEnergyCapacity","getMaxEnergyStored"}));local hasCard=select(1,first(name,set,{"hasCard"}));local mode=select(1,first(name,set,{"getMode"}));
 return{peripheral=name,source="direct",scan=scan,stored=tonumber(stored),capacity=tonumber(cap),hasCard=hasCard,mode=mode,active=scan~=nil}
end
local function snapshotReader(name,set)
 if not(set.getBlockName and set.getBlockData)then return nil end
 local nr,nok=call(name,"getBlockName");local block=nok and nr and tostring(nr[1]or"")or"";if not norm(block):find("rftoolsbuilderbuilder",1,true)then return nil end
 local dr,dok=call(name,"getBlockData");local data=dok and dr and dr[1]or nil;if type(data)~="table"then return{peripheral=name,source="block_reader",block=block,active=false,error="Builder block data unavailable"}end
 local scan=blockPos(data,"scan");local minb=blockPos(data,"minBox");local maxb=blockPos(data,"maxBox");local stored=numberfind(data,{"energy","energyStored","storedEnergy"});local cap=numberfind(data,{"maxEnergy","energyCapacity","capacity"});local mode=keyfind(data,"mode");local err=keyfind(data,"lastError")
 return{peripheral=name,source="block_reader",block=block,scan=scan,minBox=minb,maxBox=maxb,stored=stored,capacity=cap,mode=mode,lastError=err,active=scan~=nil,rawAvailable=true}
end
local function enrich(b,prev,now)
 local p,chunk,chunks,y=progress(b.scan,b.minBox,b.maxBox);b.progress=p;b.chunk=chunk;b.chunks=chunks;b.yLevel=y
 if p then b.percent=p*100 end
 local old=prev and prev.progress;local oldAt=prev and tonumber(prev.sampleAt);local rate=prev and tonumber(prev.ratePerSecond)
 if p and old and oldAt and now>oldAt then local dp=p-old;local dt=(now-oldAt)/1000;if dp>0 and dp<0.25 and dt>0 then local instant=dp/dt;rate=rate and(rate*.7+instant*.3)or instant elseif dp<0 then rate=nil end end
 b.ratePerSecond=rate;b.sampleAt=now
 if p and rate and rate>0 then b.etaSeconds=(1-p)/rate end
 if not b.active then b.status=b.lastError and"ERROR"or(b.hasCard==false and"NO CARD"or"STOPPED")elseif b.lastError and tostring(b.lastError)~=""then b.status="ERROR"else b.status="RUNNING"end
 if b.capacity and b.capacity>0 and b.stored then b.energyPercent=b.stored/b.capacity*100 end
 return b
end

function M.read(previous)
 local now=os.epoch("utc");local out={builders={},online=false,_updated=now};local oldBy={}
 for _,b in ipairs(previous and previous.builders or{})do oldBy[tostring(b.peripheral or"")]=b end
 local names=peripheral.getNames();table.sort(names)
 for _,name in ipairs(names)do
  local ts=types(name);local set=methods(name);local joined=norm(table.concat(ts," "));local b
  if joined:find("blockreader",1,true)then b=snapshotReader(name,set) end
  if not b and(joined:find("builder",1,true)or set.getScan or set.hasCard)then b=snapshotDirect(name,set) end
  if b then out.builders[#out.builders+1]=enrich(b,oldBy[tostring(name)],now)end
 end
 table.sort(out.builders,function(a,b)if a.active~=b.active then return a.active end;if a.source~=b.source then return a.source=="block_reader"end;return tostring(a.peripheral)<tostring(b.peripheral)end)
 out.count=#out.builders;out.primary=out.builders[1];out.online=#out.builders>0;out.active=out.primary and out.primary.active or false;out._status=out.online and"online"or"offline"
 return out
end
return M
