local base=require("clients.admin_v18")
local M={}
for k,v in pairs(base)do M[k]=v end

local C={bg=colors.black,text=colors.white,dim=colors.lightGray,good=colors.lime,warn=colors.orange,bad=colors.red,panel=colors.gray,sky=colors.lightBlue or colors.cyan,sun=colors.yellow or colors.orange,cloud=colors.lightGray}
local function upper(v)return tostring(v or""):upper()end
local function nice(v)return upper(tostring(v or""):gsub("minecraft:",""):gsub("[_%-]"," "):gsub("(%l)(%u)","%1 %2"))end
local function state(env)return env and env.state or{}end
local function fmt(n)local v=tonumber(n);if not v then return"?"end;local a=math.abs(v);if a>=1e15 then return string.format("%.1fP",v/1e15)elseif a>=1e12 then return string.format("%.1fT",v/1e12)elseif a>=1e9 then return string.format("%.1fG",v/1e9)elseif a>=1e6 then return string.format("%.1fM",v/1e6)elseif a>=1e3 then return string.format("%.1fK",v/1e3)end;return tostring(math.floor(v+.5))end
local function fmtDuration(sec)local n=tonumber(sec);if not n or n<0 or n~=n then return"LEARNING"end;n=math.floor(n+.5);if n<60 then return tostring(n).."s"end;local m=math.floor(n/60);if m<60 then return string.format("%dm %02ds",m,n%60)end;local h=math.floor(m/60);if h<24 then return string.format("%dh %02dm",h,m%60)end;return string.format("%dd %02dh",math.floor(h/24),h%24)end
local function gameTime()local ok,t=pcall(os.time,"ingame");t=ok and tonumber(t)or 0;local h=math.floor(t%24);local m=math.floor(((t%24)-h)*60+.5)%60;return string.format("%02d:%02d",h,m),t end
local function phase(ms)local ok,n=pcall(os.epoch,"utc");n=ok and tonumber(n)or 0;return math.floor(n/(ms or 500))end
local function hasCategory(d,wanted)for _,v in ipairs(d and d.categories or{})do if v==wanted then return true end end;return false end

local function isMonitor(n)local ok,t=pcall(peripheral.getType,n);if ok and t=="monitor"then return true end;if type(peripheral.hasType)=="function"then local ok2,v=pcall(peripheral.hasType,n,"monitor");if ok2 and v then return true end end;return false end
local function detectMonitors()local out={};local ok,names=pcall(peripheral.getNames);if not ok or type(names)~="table"then return out end;for _,n in ipairs(names)do if isMonitor(n)then local okW,m=pcall(peripheral.wrap,n);if okW and m then local scale=1;pcall(m.setTextScale,scale);local okS,w,h=pcall(m.getSize);if okS then w,h=tonumber(w),tonumber(h);if w<22 or h<12 then scale=.5;pcall(m.setTextScale,scale);local ok2,w2,h2=pcall(m.getSize);if ok2 then w,h=tonumber(w2)or w,tonumber(h2)or h end end;out[#out+1]={name=n,mon=m,w=w,h=h,scale=scale,area=w*h}end end end end;table.sort(out,function(a,b)if a.area~=b.area then return a.area>b.area end;if a.w~=b.w then return a.w>b.w end;return a.name<b.name end);return out end
local function prep(e)pcall(e.mon.setTextScale,e.scale);e.mon.setBackgroundColor(C.bg);e.mon.setTextColor(C.text);e.mon.clear()end
local function put(e,x,y,text,fg,bg)if y<1 or y>e.h or x>e.w then return end;x=math.max(1,x);text=tostring(text or"");e.mon.setCursorPos(x,y);e.mon.setTextColor(fg or C.text);e.mon.setBackgroundColor(bg or C.bg);e.mon.write(text:sub(1,math.max(0,e.w-x+1)));e.mon.setBackgroundColor(C.bg)end
local function fill(e,x1,y1,x2,y2,bg)x1,x2=math.max(1,x1),math.min(e.w,x2);y1,y2=math.max(1,y1),math.min(e.h,y2);if x2<x1 or y2<y1 then return end;for y=y1,y2 do put(e,x1,y,string.rep(" ",x2-x1+1),C.text,bg)end end
local function center(e,y,text,fg,bg,x1,x2)x1=x1 or 1;x2=x2 or e.w;local w=x2-x1+1;text=tostring(text or"");if #text>w then text=text:sub(1,w)end;put(e,x1+math.max(0,math.floor((w-#text)/2)),y,text,fg,bg)end
local function rule(e,y)if y>=1 and y<=e.h then put(e,2,y,string.rep("-",math.max(0,e.w-2)),C.panel)end end
local function header(e,title)local gt=gameTime();put(e,2,1,title,C.text);put(e,math.max(2,e.w-#gt-1),1,gt,C.dim);rule(e,3)end
local function bar(e,x1,y,x2,pct,color)local p=math.max(0,math.min(100,tonumber(pct)or 0));fill(e,x1,y,x2,y,C.panel);local n=math.floor((x2-x1+1)*p/100+.5);if n>0 then fill(e,x1,y,x1+n-1,y,color or C.good)end end

local function allSensors(env)
 local a=state(env).attachments or{};local out,seen={},{}
 local function add(d)
  local n=tostring(d.type or""):lower():gsub("[^a-z0-9]","");local j=table.concat(d.types or{}," "):lower()
  if n:find("environmentdetector",1,true)or n:find("blockreader",1,true)or j:find("block_reader",1,true)or j:find("me_bridge",1,true)then return end
  if not(hasCategory(d,"sensor")or hasCategory(d,"sensor_candidate"))then return end
  local k=tostring(d._source or"").."|"..tostring(d.name or d.type);if not seen[k]then seen[k]=true;out[#out+1]=d end
 end
 for _,d in ipairs(a.devices or{})do add(d)end;for _,d in ipairs(a.sensors or{})do add(d)end
 table.sort(out,function(a,b)return tostring(a.name or a.type)<tostring(b.name or b.type)end);return out
end

local function drawSun(e,x,y,p)
 local rays=(p%2==0)and{{0,-2},{0,2},{-4,0},{4,0},{-3,-1},{3,-1},{-3,1},{3,1}}or{{0,-2},{0,2},{-3,0},{3,0},{-2,-1},{2,-1},{-2,1},{2,1}}
 put(e,x-1,y,"OOO",C.sun);put(e,x-1,y-1,"OOO",C.sun);put(e,x-1,y+1,"OOO",C.sun)
 for _,r in ipairs(rays)do put(e,x+r[1],y+r[2],(r[1]==0 and"|"or(r[2]==0 and"-"or"*")),C.sun)end
end
local function drawMoon(e,x,y,p)put(e,x-2,y-1," .OO",C.cloud);put(e,x-2,y,"OOOO",C.cloud);put(e,x-2,y+1," 'OO",C.cloud);local stars={{-8,-2},{7,-2},{-6,2},{8,1},{-10,0},{5,3}};for i,s in ipairs(stars)do if(i+p)%2==0 then put(e,x+s[1],y+s[2],"*",C.text)end end end
local function drawRain(e,x1,y1,x2,y2,p,thunder)
 center(e,y1,".---- CLOUD ----.",C.cloud,nil,x1,x2);local chars={"|","/","|","\\"}
 for y=y1+2,y2 do local start=x1+((y+p)%3);for x=start,x2,4 do put(e,x,y,chars[((x+y+p)%#chars)+1],C.sky)end end
 if thunder then local x=math.floor((x1+x2)/2)+(p%3)-1;put(e,x,y1+2,"\\",C.sun);put(e,x-1,y1+3,"/",C.sun);put(e,x,y1+4,"\\",C.sun);if p%6==0 then fill(e,x1,y1+1,x2,math.min(y2,y1+2),colors.white or C.cloud)end end
end
local function renderEnvironmentAnimated(e,env)
 prep(e);header(e,"ENVIRONMENT // LIVE");local en=state(env).environment or{};local weather=upper(en.weather or"UNKNOWN");local p=phase(500);local _,t=gameTime();local hour=(tonumber(t)or 0)%24;local daytime=hour>=6 and hour<18
 center(e,5,weather,weather=="THUNDER"and C.bad or(weather=="RAINING"and C.warn or C.good))
 local artTop=7;local artBottom=math.min(e.h>=24 and 16 or 12,e.h-7);local mid=math.floor(e.w/2)
 if weather=="RAINING"or weather=="THUNDER"then drawRain(e,math.max(2,mid-12),artTop,math.min(e.w-2,mid+12),artBottom,p,weather=="THUNDER")elseif daytime then drawSun(e,mid,math.min(10,artBottom-2),p)else drawMoon(e,mid,math.min(10,artBottom-2),p)end
 local y=artBottom+2;if y<=e.h then rule(e,y);y=y+1 end
 if e.w>=38 then put(e,2,y,"BIOME",C.dim);put(e,10,y,nice(en.biome or"UNKNOWN"),C.text);put(e,math.floor(e.w/2),y,"DIM",C.dim);put(e,math.floor(e.w/2)+5,y,nice(en.dimension or"UNKNOWN"),C.text);y=y+2;put(e,2,y,"MOON",C.dim);put(e,8,y,nice(en.moon or"UNKNOWN"),C.text);put(e,math.floor(e.w/2),y,"LIGHT",C.dim);put(e,math.floor(e.w/2)+7,y,tostring(en.blockLight or"?").." / SKY "..tostring(en.skyLight or"?"),C.text)
 else put(e,2,y,"BIOME "..nice(en.biome or"UNKNOWN"),C.text);y=y+2;if y<=e.h then put(e,2,y,"MOON "..nice(en.moon or"UNKNOWN"),C.dim)end;y=y+2;if y<=e.h then put(e,2,y,"LIGHT "..tostring(en.blockLight or"?").." / SKY "..tostring(en.skyLight or"?"),C.text)end end
end

local function renderAE2(e,env)
 prep(e);header(e,"AE2 SYSTEM");local a=state(env).ae2 or{};local on=a.online==true;put(e,2,5,on and"NETWORK ONLINE"or(a.connected and"BRIDGE CONNECTED / AE OFFLINE"or"NO ME BRIDGE"),on and C.good or C.warn)
 if a.bridge then put(e,2,6,nice(a.bridge),C.dim)end;rule(e,8)
 local y=10;put(e,2,y,"ITEMS",C.dim);put(e,12,y,fmt(a.itemCount or a.items),C.text);y=y+2;put(e,2,y,"ITEM TYPES",C.dim);put(e,12,y,fmt(a.itemTypes),C.text);y=y+2;put(e,2,y,"CRAFT JOBS",C.dim);put(e,12,y,fmt(a.craftingJobs),tonumber(a.craftingJobs or 0)>0 and C.warn or C.good);y=y+2
 if a.energyCapacity then local ep=(tonumber(a.storedEnergy)or 0)/math.max(1,tonumber(a.energyCapacity)or 1)*100;put(e,2,y,"AE ENERGY "..string.format("%.1f%%",ep),C.dim);if y+1<=e.h then bar(e,2,y+1,e.w-2,ep,C.good)end;y=y+3 end
 if y<=e.h then put(e,2,y,"USAGE "..fmt(a.energyUsage).." AE/t",C.dim);y=y+1 end;if y<=e.h then put(e,2,y,"INJECT "..fmt(a.avgPowerInjection).." AE/t",C.good);y=y+2 end
 if y<=e.h and(a.usedItemStorage or a.totalItemStorage)then put(e,2,y,"ITEM STORAGE",C.dim);y=y+1;if y<=e.h then put(e,2,y,fmt(a.usedItemStorage).." / "..fmt(a.totalItemStorage),C.text)end end
end

local function renderBuilder(e,env)
 prep(e);header(e,"QUARRY // BUILDER");local bstate=state(env).builder or{};local b=bstate.primary or(bstate.builders and bstate.builders[1])
 if not b then center(e,6,"NO BUILDER TELEMETRY",C.warn);center(e,8,"BLOCK READER -> BUILDER",C.dim);center(e,9,"KIMI NODE -> NETWORK",C.dim);return end
 put(e,2,5,upper(b.status or(b.active and"RUNNING"or"STOPPED")),b.status=="ERROR"and C.bad or(b.active and C.good or C.warn));put(e,math.max(2,e.w-#tostring(b.source or"")-2),5,upper(b.source or""),C.dim)
 if b.percent then center(e,7,string.format("%.1f%% COMPLETE",b.percent),C.good);bar(e,2,8,e.w-2,b.percent,C.good);put(e,2,10,"ETA",C.dim);put(e,8,10,fmtDuration(b.etaSeconds),b.etaSeconds and C.text or C.warn);if b.chunk then put(e,2,12,"CHUNK",C.dim);put(e,10,12,tostring(b.chunk).." / "..tostring(b.chunks or"?"),C.text)end;if b.yLevel then put(e,2,14,"Y LEVEL",C.dim);put(e,10,14,tostring(b.yLevel),C.text)end
 elseif b.scan then center(e,7,"SCAN "..tostring(b.scan.x)..","..tostring(b.scan.y)..","..tostring(b.scan.z),C.text);center(e,9,"ETA NEEDS MIN/MAX BOX DATA",C.warn)
 else center(e,7,"BUILDER STOPPED / COMPLETE",C.dim)end
 local y=e.h-5;if y>15 then rule(e,y);y=y+1;if b.energyPercent then put(e,2,y,"ENERGY "..string.format("%.1f%%",b.energyPercent),C.dim);y=y+1 end;if b.stored then put(e,2,y,fmt(b.stored).." FE",C.text);y=y+1 end;if b.lastError and tostring(b.lastError)~=""then put(e,2,y,"ERR "..tostring(b.lastError),C.bad)end end
end

local function sensorRows(s)local m=s and s.metrics or{};local r={};local function add(k,v)if v~=nil then r[#r+1]={k,tostring(v)}end end;add("TEMP",m.temperature);add("HUMIDITY",m.humidity);add("PRESSURE",m.pressure);if m.radiationRaw~=nil then add("RADIATION",m.radiationRaw)elseif m.radiationText~=nil then add("RADIATION",m.radiationText)end;if m.onlinePlayers~=nil then add("PLAYERS",m.onlinePlayers)elseif m.playerCount~=nil then add("PLAYERS",m.playerCount)end;add("ENTITIES",m.entityCount);add("BLOCK LIGHT",m.blockLight);add("SKY LIGHT",m.skyLight);return r end
local function renderSensor(e,s,index,total)
 prep(e);header(e,"SENSOR "..index.."/"..total);if not s then center(e,7,"NO SENSOR DATA",C.dim);return end;put(e,2,5,nice(s.reportedName or s.name or s.type),C.text);if s._source then put(e,2,6,"NODE "..tostring(s._source),C.dim)end;rule(e,8);local rows=sensorRows(s);local y=10;put(e,2,y,nice(s.summary or"ONLINE"),C.good);y=y+2;for _,r in ipairs(rows)do if y>e.h then break end;put(e,2,y,r[1],C.dim);if y+1<=e.h then put(e,2,y+1,r[2],C.text)end;y=y+3 end
end
local function renderSystems(e,env)
 prep(e);header(e,"KIMI SYSTEMS");local s=state(env);local a=s.ae2 or{};local b=s.builder or{};local sensors=allSensors(env);put(e,2,5,"VERSION",C.dim);put(e,2,6,tostring(env and env.version or"?"),C.text);rule(e,8);put(e,2,10,"AE2",C.dim);put(e,12,10,a.online and"ONLINE"or"OFFLINE",a.online and C.good or C.warn);put(e,2,12,"BUILDER",C.dim);put(e,12,12,b.online and"ONLINE"or"OFFLINE",b.online and C.good or C.dim);put(e,2,14,"SENSORS",C.dim);put(e,12,14,tostring(#sensors),#sensors>0 and C.good or C.warn);put(e,2,16,"WEATHER",C.dim);put(e,12,16,upper(s.environment and s.environment.weather or"UNKNOWN"),C.text)
end

local function popBest(list,score)
 if #list==0 then return nil end;local bi,bs=1,-math.huge;for i,e in ipairs(list)do local s=score(e);if s>bs then bi,bs=i,s end end;return table.remove(list,bi)
end
local function responsiveScore(e)return(e.w/math.max(1,e.h))*1000+e.area end
function M.init(c)return base.init(c)end
function M.render(env,meta)
 local ok=base.render(env,meta);local mons=detectMonitors();local extra={};for i=4,#mons do extra[#extra+1]=mons[i]end;if #extra==0 then return ok end
 local envMon=popBest(extra,responsiveScore);if envMon then renderEnvironmentAnimated(envMon,env)end
 local ae=state(env).ae2 or{};if #extra>0 and(ae.online or ae.connected or ae.bridge)then local m=popBest(extra,function(e)return e.area end);renderAE2(m,env)end
 local bs=state(env).builder or{};if #extra>0 and(bs.online or bs.primary or(bs.builders and#bs.builders>0))then local m=popBest(extra,function(e)return e.area end);renderBuilder(m,env)end
 local sensors=allSensors(env);local rot=phase(6000);for i,e in ipairs(extra)do if #sensors>0 then local idx=((rot+i-2)%#sensors)+1;renderSensor(e,sensors[idx],idx,#sensors)else renderSystems(e,env)end end
 return ok
end
return M
