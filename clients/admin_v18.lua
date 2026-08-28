local base=require("clients.admin_v17")
local M={}
for k,v in pairs(base)do M[k]=v end

local C={bg=colors.black,text=colors.white,dim=colors.lightGray,good=colors.lime,warn=colors.orange,bad=colors.red,panel=colors.gray}

local function upper(v)return tostring(v or""):upper()end
local function nice(v)return upper(tostring(v or""):gsub("minecraft:",""):gsub("[_%-]"," "):gsub("(%l)(%u)","%1 %2"))end
local function state(env)return env and env.state or{}end
local function baseName()local l=type(os.getComputerLabel)=="function"and os.getComputerLabel()or nil;return upper(l or"KIMI")end
local function gameTime()local ok,t=pcall(os.time,"ingame");t=ok and tonumber(t)or 0;local h=math.floor(t%24);local m=math.floor(((t%24)-h)*60+.5)%60;return string.format("%02d:%02d",h,m)end
local function fmt(n)local v=tonumber(n);if not v then return"?"end;local a=math.abs(v);if a>=1e15 then return string.format("%.1fP",v/1e15)elseif a>=1e12 then return string.format("%.1fT",v/1e12)elseif a>=1e9 then return string.format("%.1fG",v/1e9)elseif a>=1e6 then return string.format("%.1fM",v/1e6)elseif a>=1e3 then return string.format("%.1fK",v/1e3)end;return tostring(math.floor(v+.5))end
local function percent(p)local n=tonumber(p and p.filledPercentage);if n then if n<=1 then n=n*100 end;return math.max(0,math.min(100,n))end;local s,c=tonumber(p and p.stored),tonumber(p and p.capacity);if s and c and c>0 then return math.max(0,math.min(100,s/c*100))end end
local function fmtDuration(sec)sec=tonumber(sec);if not sec or sec<0 or sec~=sec then return"?"end;sec=math.floor(sec+.5);if sec<60 then return tostring(sec).."s"end;local m=math.floor(sec/60);local s=sec%60;if m<60 then return string.format("%dm %02ds",m,s)end;local h=math.floor(m/60);m=m%60;if h<24 then return string.format("%dh %02dm",h,m)end;local d=math.floor(h/24);h=h%24;return string.format("%dd %02dh",d,h)end
local function powerStatus(p)local stored=tonumber(p and p.stored);local cap=tonumber(p and p.capacity);local input=tonumber(p and p.input)or 0;local output=tonumber(p and p.output)or 0;local net=tonumber(p and p.net);if net==nil then net=input-output end;local activity=math.max(math.abs(input),math.abs(output),1);if math.abs(net)<=math.max(1,activity*.002)then return"HOLDING"end;if not stored or not cap or cap<=0 then return net>0 and"CHARGING"or"DRAINING"end;if net>0 then if stored>=cap then return"FULL"end;return"FULL IN "..fmtDuration((cap-stored)/(net*20))end;if stored<=0 then return"EMPTY"end;return"EMPTY IN "..fmtDuration(stored/((-net)*20))end
local function hasCategory(d,wanted)for _,v in ipairs(d and d.categories or{})do if v==wanted then return true end end;return false end

local function isMonitor(n)local ok,t=pcall(peripheral.getType,n);if ok and t=="monitor"then return true end;if type(peripheral.hasType)=="function"then local ok2,v=pcall(peripheral.hasType,n,"monitor");if ok2 and v then return true end end;return false end
local function detectMonitors()local out={};local ok,names=pcall(peripheral.getNames);if not ok or type(names)~="table"then return out end;for _,n in ipairs(names)do if isMonitor(n)then local okW,m=pcall(peripheral.wrap,n);if okW and m then local scale=1;pcall(m.setTextScale,scale);local okS,w,h=pcall(m.getSize);if okS then w,h=tonumber(w),tonumber(h);if w<22 or h<12 then scale=.5;pcall(m.setTextScale,scale);local ok2,w2,h2=pcall(m.getSize);if ok2 then w,h=tonumber(w2)or w,tonumber(h2)or h end end;out[#out+1]={name=n,mon=m,w=w,h=h,scale=scale,area=w*h}end end end end;table.sort(out,function(a,b)if a.area~=b.area then return a.area>b.area end;if a.w~=b.w then return a.w>b.w end;return a.name<b.name end);return out end
local function prep(e)pcall(e.mon.setTextScale,e.scale);e.mon.setBackgroundColor(C.bg);e.mon.setTextColor(C.text);e.mon.clear()end
local function put(e,x,y,text,fg,bg)if y<1 or y>e.h or x>e.w then return end;x=math.max(1,x);text=tostring(text or"");e.mon.setCursorPos(x,y);e.mon.setTextColor(fg or C.text);e.mon.setBackgroundColor(bg or C.bg);e.mon.write(text:sub(1,math.max(0,e.w-x+1)));e.mon.setBackgroundColor(C.bg)end
local function fill(e,x1,y1,x2,y2,bg)x1,x2=math.max(1,x1),math.min(e.w,x2);y1,y2=math.max(1,y1),math.min(e.h,y2);if x2<x1 or y2<y1 then return end;for y=y1,y2 do put(e,x1,y,string.rep(" ",x2-x1+1),C.text,bg)end end
local function center(e,y,text,fg,bg,x1,x2)x1=x1 or 1;x2=x2 or e.w;local w=x2-x1+1;text=tostring(text or"");if #text>w then text=text:sub(1,w)end;put(e,x1+math.max(0,math.floor((w-#text)/2)),y,text,fg,bg)end
local function rule(e,y)if y>=1 and y<=e.h then put(e,2,y,string.rep("-",math.max(0,e.w-2)),C.panel)end end
local function header(e,title)put(e,2,1,title,C.text);put(e,math.max(2,e.w-6),1,gameTime(),C.dim);put(e,2,2,baseName(),C.dim);rule(e,3)end

local function allSensors(env)local a=state(env).attachments or{};local out,seen={},{};for _,d in ipairs(a.devices or{})do if hasCategory(d,"sensor")or hasCategory(d,"sensor_candidate")then local k=tostring(d._source or"").."|"..tostring(d.name or d.type);if not seen[k]then seen[k]=true;out[#out+1]=d end end end;for _,d in ipairs(a.sensors or{})do local k=tostring(d._source or"").."|"..tostring(d.name or d.type);if not seen[k]then seen[k]=true;out[#out+1]=d end end;table.sort(out,function(a,b)return tostring(a.name or a.type)<tostring(b.name or b.type)end);return out end
local function chooseMain(raw,rs)local best,score=nil,-1;for _,m in ipairs(raw.matrices or{})do local data=upper(m._telemetryStatus or"LIVE");local s=(data=="LIVE"and 1e35 or(data=="CACHED"and 1e34 or 0))+(tostring(m.peripheral)==tostring(rs.mainPeripheral)and 1e30 or 0)+(tonumber(m.capacity)or 0);if s>score then best,score=m,s end end;return best or raw.matrices and raw.matrices[1] or raw end
local function reserveText(rs,raw)local st=upper(rs and rs.status or"");if st=="NO RESERVE MATRIX"then return"NOT INSTALLED"end;if st=="NO MAIN MATRIX"and raw and #(raw.matrices or{})>0 then return"NOT INSTALLED"end;if st==""then return"NOT INSTALLED"end;return st end

local function renderPowerWide(e,env)
 prep(e);header(e,"POWER")
 local raw=state(env).power or{};local rs=state(env).power_reserve or{};local main=chooseMain(raw,rs);local mp=percent(main);local fx=raw.fluxNetworks or{}
 local gap=2;local col=math.max(10,math.floor((e.w-6)/3));local x1=2;local x2=math.min(e.w-2,x1+col-1);local x3=x2+gap+1;local x4=math.min(e.w-2,x3+col-1);local x5=x4+gap+1
 put(e,x1,5,"MAIN MATRIX",C.dim);put(e,x1,6,mp and string.format("%.1f%%",mp)or"NO MATRIX",mp and C.good or C.warn)
 fill(e,x1,7,x2,7,C.panel);if mp then local bw=math.floor((x2-x1+1)*mp/100+.5);if bw>0 then fill(e,x1,7,x1+bw-1,7,C.good)end end
 put(e,x1,9,powerStatus(main),C.text);put(e,x1,10,"STORED "..fmt(main and main.stored).." FE",C.text);if e.h>=12 then put(e,x1,11,"IN +"..fmt(main and main.input).." /t",C.good);put(e,x1,12,"OUT -"..fmt(main and main.output).." /t",C.dim)end
 if x3<=e.w-2 then put(e,x3,5,"RESERVE",C.dim);put(e,x3,6,reserveText(rs,raw),rs.feeding and C.warn or(rs.configured and C.good or C.dim));put(e,x3,8,rs.reservePercent and string.format("%.1f%%",tonumber(rs.reservePercent)or 0)or"NO BACKUP MATRIX",rs.reservePercent and C.good or C.dim);put(e,x3,10,string.format("FEED <= %.0f%%",tonumber(rs.lowPercent)or 20),C.dim);if e.h>=12 then put(e,x3,11,string.format("STOP >= %.0f%%",tonumber(rs.highPercent)or 80),C.dim)end end
 if x5<=e.w-2 then put(e,x5,5,"FLUX NETWORKS",C.dim);put(e,x5,6,tostring(#fx),#fx>0 and C.good or C.warn);local y=8;for i,n in ipairs(fx)do if y>e.h then break end;put(e,x5,y,nice(n.networkName or n.peripheral or("NETWORK "..i)),C.text);if y+1<=e.h then put(e,x5,y+1,fmt(n.stored).." FE  NET "..fmt(n.net).."/t",C.dim)end;y=y+2 end end
end

local function renderPowerTall(e,env)
 prep(e);header(e,"POWER");local raw=state(env).power or{};local rs=state(env).power_reserve or{};local main=chooseMain(raw,rs);local mp=percent(main);local data=upper(main and(main._telemetryStatus or"LIVE")or"MISSING");local live=data=="LIVE";local dataColor=live and C.good or C.warn
 center(e,5,"MAIN MATRIX",C.dim);center(e,6,mp and(string.format("%.1f%%",mp).." "..data)or"NO MATRIX",mp and dataColor or C.warn)
 local x1=math.floor(e.w/2)-3;local x2=x1+6;local y1=8;local y2=math.min(15,e.h-12);if y2<y1+4 then y2=y1+4 end;fill(e,x1,y1,x2,y2,C.panel);fill(e,x1+1,y1+1,x2-1,y2-1,C.bg);local ih=y2-y1-1;local rows=mp and math.floor(ih*mp/100+.5)or 0;if rows>0 then fill(e,x1+1,y2-rows,x2-1,y2-1,dataColor)end
 local y=y2+1;center(e,y,powerStatus(main),live and C.text or C.warn);y=y+2;put(e,2,y,"STORED "..fmt(main and main.stored).." FE",C.text);y=y+1;put(e,2,y,"IN +"..fmt(main and main.input).." /t",dataColor);y=y+1;put(e,2,y,"OUT -"..fmt(main and main.output).." /t",C.dim);y=y+2;if y<=e.h then rule(e,y)end;y=y+1;if y<=e.h then put(e,2,y,"RESERVE",C.dim)end;y=y+1;if y<=e.h then put(e,2,y,live and reserveText(rs,raw)or"WAITING FOR LIVE MAIN",live and(rs.feeding and C.warn or(rs.configured and C.good or C.dim))or C.warn)end;y=y+2;local fx=raw.fluxNetworks or{};if y<=e.h then local liveFlux=0;for _,n in ipairs(fx)do if upper(n._telemetryStatus or"LIVE")=="LIVE"then liveFlux=liveFlux+1 end end;put(e,2,y,"FLUX "..#fx.." / "..liveFlux.." LIVE",#fx>0 and(liveFlux>0 and C.good or C.warn)or C.warn)end
end

local function renderEnvironment(e,env)
 prep(e);header(e,"ENVIRONMENT");local en=state(env).environment or{};local weather=upper(en.weather or"UNKNOWN");center(e,5,weather,weather=="THUNDER"and C.bad or(weather=="RAINING"and C.warn or C.good))
 if e.w>=40 then local split=math.floor(e.w/2);put(e,2,7,"BIOME",C.dim);put(e,2,8,nice(en.biome or"UNKNOWN"),C.text);put(e,2,10,"DIMENSION",C.dim);put(e,2,11,nice(en.dimension or"UNKNOWN"),C.text);put(e,split+1,7,"MOON",C.dim);put(e,split+1,8,nice(en.moon or"UNKNOWN"),C.text);put(e,split+1,10,"LIGHT",C.dim);put(e,split+1,11,tostring(en.blockLight or"?").." / SKY "..tostring(en.skyLight or"?"),C.text)
 else put(e,2,7,"BIOME",C.dim);put(e,2,8,nice(en.biome or"UNKNOWN"),C.text);put(e,2,10,"DIM",C.dim);put(e,2,11,nice(en.dimension or"UNKNOWN"),C.text);put(e,2,13,"MOON",C.dim);put(e,2,14,nice(en.moon or"UNKNOWN"),C.text);put(e,2,16,"LIGHT "..tostring(en.blockLight or"?").." / SKY "..tostring(en.skyLight or"?"),C.text)end
end

local function metricRows(s)local m=s and s.metrics or{};local rows={};local function add(k,v)if v~=nil then rows[#rows+1]={k,tostring(v)}end end;add("TEMP",m.temperature);add("HUMIDITY",m.humidity);add("PRESSURE",m.pressure);if m.radiationRaw~=nil then add("RADIATION",m.radiationRaw)elseif m.radiationText~=nil then add("RADIATION",m.radiationText)end;if m.onlinePlayers~=nil then add("PLAYERS",m.onlinePlayers)elseif m.playerCount~=nil then add("PLAYERS",m.playerCount)end;add("ENTITIES",m.entityCount);add("BLOCK LIGHT",m.blockLight);add("SKY LIGHT",m.skyLight);return rows end
local function renderSensorCard(e,s,index,total)
 prep(e);header(e,"SENSOR "..index.."/"..total);if not s then center(e,7,"NO ADDITIONAL SENSOR",C.dim);return end
 put(e,2,5,nice(s.reportedName or s.name or s.type or("SENSOR "..index)),C.text);if s._source then put(e,2,6,"NODE "..tostring(s._source),C.dim)end;rule(e,8);put(e,2,10,"STATUS",C.dim);put(e,2,11,nice(s.summary or"ONLINE"),C.good)
 local rows=metricRows(s);local y=13;for _,r in ipairs(rows)do if y>e.h then break end;put(e,2,y,r[1],C.dim);if y+1<=e.h then put(e,2,y+1,r[2],C.text)end;y=y+3 end
 if #rows==0 and y<=e.h then put(e,2,y,"CATEGORIES",C.dim);if y+1<=e.h then put(e,2,y+1,nice(table.concat(s.categories or{}," / ")),C.text)end end
end

local function chooseEnvironmentMonitor(extras)local best,bestScore=nil,-1;for _,e in ipairs(extras)do local aspect=(tonumber(e.w)or 0)/math.max(1,tonumber(e.h)or 1);local score=aspect*1000+e.area;if score>bestScore then best,bestScore=e,score end end;return best end

function M.init(c)return base.init(c)end
function M.render(env,meta)
 local ok=base.render(env,meta);local mons=detectMonitors()
 if mons[2]then if mons[2].w>=mons[2].h*1.45 then renderPowerWide(mons[2],env)else renderPowerTall(mons[2],env)end end
 local extras={};for i=4,#mons do extras[#extras+1]=mons[i]end
 if #extras>0 then local envMon=chooseEnvironmentMonitor(extras);renderEnvironment(envMon,env);local sensorMons={};for _,e in ipairs(extras)do if e.name~=envMon.name then sensorMons[#sensorMons+1]=e end end;table.sort(sensorMons,function(a,b)if a.h~=b.h then return a.h>b.h end;return a.name<b.name end);local sensors=allSensors(env);for i,e in ipairs(sensorMons)do renderSensorCard(e,sensors[i],i,#sensors)end end
 return ok
end
function M.onPeripheralChange(...)if base.onPeripheralChange then return base.onPeripheralChange(...)end end
function M.handleEvent(...)if base.handleEvent then return base.handleEvent(...)end;return false end
return M
