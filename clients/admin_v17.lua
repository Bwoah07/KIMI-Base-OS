local base=require("clients.admin_v16")
local M={}
for k,v in pairs(base)do M[k]=v end

local cfg={}
local view="home"
local lastEnv,lastMeta
local C={bg=colors.black,text=colors.white,dim=colors.lightGray,good=colors.lime,warn=colors.orange,bad=colors.red,panel=colors.gray,accent=colors.cyan or colors.lightBlue}
local glyphs={["0"]={"111","101","101","101","111"},["1"]={"010","110","010","010","111"},["2"]={"111","001","111","100","111"},["3"]={"111","001","111","001","111"},["4"]={"101","101","111","001","001"},["5"]={"111","100","111","001","111"},["6"]={"111","100","111","101","111"},["7"]={"111","001","010","010","010"},["8"]={"111","101","111","101","111"},["9"]={"111","101","111","001","111"},[":"]={"0","1","0","1","0"}}

local function upper(v)return tostring(v or""):upper()end
local function nice(v)return upper(tostring(v or""):gsub("minecraft:",""):gsub("[_%-]"," "):gsub("(%l)(%u)","%1 %2"))end
local function state(env)return env and env.state or{}end
local function gameTime()local ok,t=pcall(os.time,"ingame");t=ok and tonumber(t)or 0;local h=math.floor(t%24);local m=math.floor(((t%24)-h)*60+.5)%60;return string.format("%02d:%02d",h,m)end
local function fmt(n)local v=tonumber(n);if not v then return"?"end;local a=math.abs(v);if a>=1e15 then return string.format("%.1fP",v/1e15)elseif a>=1e12 then return string.format("%.1fT",v/1e12)elseif a>=1e9 then return string.format("%.1fG",v/1e9)elseif a>=1e6 then return string.format("%.1fM",v/1e6)elseif a>=1e3 then return string.format("%.1fK",v/1e3)end;return tostring(math.floor(v+.5))end
local function percent(p)
 local n=tonumber(p and p.filledPercentage);if n then if n<=1 then n=n*100 end;return math.max(0,math.min(100,n))end
 local st,cap=tonumber(p and p.stored),tonumber(p and p.capacity);if st and cap and cap>0 then return math.max(0,math.min(100,st/cap*100))end
end
local function fmtDuration(sec)
 sec=tonumber(sec);if not sec or sec<0 or sec~=sec then return"?"end;sec=math.floor(sec+.5)
 if sec<60 then return tostring(sec).."s"end
 local m=math.floor(sec/60);local s=sec%60;if m<60 then return string.format("%dm %02ds",m,s)end
 local h=math.floor(m/60);m=m%60;if h<24 then return string.format("%dh %02dm",h,m)end
 local d=math.floor(h/24);h=h%24;return string.format("%dd %02dh",d,h)
end
local function powerStatus(p)
 local stored=tonumber(p and p.stored);local cap=tonumber(p and p.capacity)
 local input=tonumber(p and p.input)or 0;local output=tonumber(p and p.output)or 0
 local net=tonumber(p and p.net);if net==nil then net=input-output end
 local activity=math.max(math.abs(input),math.abs(output),1);local threshold=math.max(1,activity*.002)
 if math.abs(net)<=threshold then return"HOLDING"end
 if not stored or not cap or cap<=0 then return net>0 and"CHARGING"or"DRAINING"end
 if net>0 then if stored>=cap then return"FULL"end;return"FULL IN "..fmtDuration((cap-stored)/(net*20))end
 if stored<=0 then return"EMPTY"end;return"EMPTY IN "..fmtDuration(stored/((-net)*20))
end
local function hasCategory(d,wanted)for _,v in ipairs(d and d.categories or{})do if v==wanted then return true end end;return false end

local function isMonitor(n)local ok,t=pcall(peripheral.getType,n);if ok and t=="monitor"then return true end;if type(peripheral.hasType)=="function"then local ok2,v=pcall(peripheral.hasType,n,"monitor");if ok2 and v then return true end end;return false end
local function detectMonitors()
 local out={};local ok,names=pcall(peripheral.getNames);if not ok or type(names)~="table"then return out end
 for _,n in ipairs(names)do if isMonitor(n)then local okW,m=pcall(peripheral.wrap,n);if okW and m then local scale=1;pcall(m.setTextScale,scale);local okS,w,h=pcall(m.getSize);if okS then w,h=tonumber(w),tonumber(h);if w<22 or h<12 then scale=.5;pcall(m.setTextScale,scale);local ok2,w2,h2=pcall(m.getSize);if ok2 then w,h=tonumber(w2)or w,tonumber(h2)or h end end;out[#out+1]={name=n,mon=m,w=w,h=h,scale=scale,area=w*h}end end end end
 table.sort(out,function(a,b)if a.area~=b.area then return a.area>b.area end;if a.w~=b.w then return a.w>b.w end;return a.name<b.name end);return out
end
local function put(e,x,y,text,fg,bg)if y<1 or y>e.h or x>e.w then return end;x=math.max(1,x);text=tostring(text or"");e.mon.setCursorPos(x,y);e.mon.setTextColor(fg or C.text);e.mon.setBackgroundColor(bg or C.bg);e.mon.write(text:sub(1,math.max(0,e.w-x+1)));e.mon.setBackgroundColor(C.bg)end
local function fill(e,x1,y1,x2,y2,bg)x1,x2=math.max(1,x1),math.min(e.w,x2);y1,y2=math.max(1,y1),math.min(e.h,y2);if x2<x1 or y2<y1 then return end;for y=y1,y2 do put(e,x1,y,string.rep(" ",x2-x1+1),C.text,bg)end end
local function center(e,y,text,fg,bg,x1,x2)x1,x2=x1 or 1,x2 or e.w;local w=x2-x1+1;text=tostring(text or"");if #text>w then text=text:sub(1,w)end;put(e,x1+math.max(0,math.floor((w-#text)/2)),y,text,fg,bg)end
local function rule(e,y)put(e,2,y,string.rep("-",math.max(0,e.w-2)),C.panel)end
local function clearBody(e)fill(e,1,4,e.w,e.h-3,C.bg)end

local function bigClock(e,y,x1,x2)
 local value=gameTime();local scale=(x2-x1+1)>=42 and 2 or 1;local widths,total={},0
 for i=1,#value do local ch=value:sub(i,i);widths[i]=(ch==":"and 1 or 3)*scale;total=total+widths[i]+(i<#value and 1 or 0)end
 local x=x1+math.max(0,math.floor(((x2-x1+1)-total)/2))
 for i=1,#value do local ch=value:sub(i,i);local rows=glyphs[ch];local cols=ch==":"and 1 or 3;for r=1,5 do for c=1,cols do if rows[r]:sub(c,c)=="1"then fill(e,x+(c-1)*scale,y+r-1,x+c*scale-1,y+r-1,C.text)end end end;x=x+widths[i]+1 end
end
local function environment(env)
 local e=state(env).environment or{}
 if e.online==false then return e,"ENVIRONMENT OFFLINE"end
 return e,upper(e.weather or"UNKNOWN")
end
local function allSensors(env)
 local a=state(env).attachments or{};local out={};local seen={}
 for _,d in ipairs(a.devices or{})do if hasCategory(d,"sensor")or hasCategory(d,"sensor_candidate")then local k=tostring(d._source or"").."|"..tostring(d.name or d.type);if not seen[k]then seen[k]=true;out[#out+1]=d end end end
 for _,d in ipairs(a.sensors or{})do local k=tostring(d._source or"").."|"..tostring(d.name or d.type);if not seen[k]then seen[k]=true;out[#out+1]=d end end
 table.sort(out,function(a,b)return tostring(a.name or a.type)<tostring(b.name or b.type)end);return out
end
local function metricLine(s)
 local m=s.metrics or{};local bits={}
 local function add(label,v)if v~=nil and #bits<4 then bits[#bits+1]=label..tostring(v)end end
 add("T ",m.temperature);add("H ",m.humidity);add("P ",m.pressure)
 if m.radiationRaw~=nil then add("RAD ",m.radiationRaw)elseif m.radiationText~=nil then add("RAD ",m.radiationText)end
 if m.onlinePlayers~=nil then add("PLAYERS ",m.onlinePlayers)elseif m.playerCount~=nil then add("PLAYERS ",m.playerCount)end
 add("ENT ",m.entityCount);add("LIGHT ",m.blockLight);add("SKY ",m.skyLight)
 if m.weatherThunder then add("","THUNDER")elseif m.weatherRaining then add("","RAIN")elseif m.weatherSunny then add("","SUNNY")end
 if #bits==0 then return nice(s.summary or"ONLINE")end
 return table.concat(bits,"  ")
end

local function chooseMainMatrix(raw,reserveState)
 local best,score=nil,-1
 for _,m in ipairs(raw.matrices or{})do local s=(tostring(m.peripheral)==tostring(reserveState.mainPeripheral)and 1e30 or 0)+(tonumber(m.capacity)or 0);if s>score then best,score=m,s end end
 return best or raw.matrices and raw.matrices[1] or raw
end
local function flux(env)return(state(env).power or{}).fluxNetworks or{}end

local function drawHome(e,env)
 clearBody(e);local split=math.floor(e.w*.50)
 put(e,2,5,"BASE TIME",C.dim);bigClock(e,7,2,split-2)
 local en,weather=environment(env);local x=split+2
 put(e,x,5,"ENVIRONMENT",C.dim);put(e,e.w-#weather-2,5,weather,weather=="THUNDER"and C.bad or(weather=="RAINING"and C.warn or C.good))
 put(e,x,7,"BIOME",C.dim);put(e,x,8,nice(en.biome or"UNKNOWN"),C.text)
 put(e,x,10,"DIMENSION",C.dim);put(e,x,11,nice(en.dimension or"UNKNOWN"),C.text)
 put(e,x,13,"MOON",C.dim);put(e,x,14,nice(en.moon or"UNKNOWN"),C.text)
 put(e,x,16,"LIGHT",C.dim);put(e,x+7,16,tostring(en.blockLight or"?").." / SKY "..tostring(en.skyLight or"?"),C.text)
 rule(e,e.h-7)
 local ss=allSensors(env);local raw=state(env).power or{};local rs=state(env).power_reserve or{};local main=chooseMainMatrix(raw,rs);local mp=percent(main);local fx=flux(env)
 put(e,2,e.h-6,"SENSORS",C.dim);put(e,10,e.h-6,tostring(#ss),#ss>0 and C.good or C.warn)
 put(e,16,e.h-6,"MAIN",C.dim);put(e,22,e.h-6,mp and string.format("%.1f%%",mp)or"NO MATRIX",mp and C.good or C.warn)
 put(e,34,e.h-6,"RESERVE",C.dim);put(e,42,e.h-6,upper(rs.status or"NOT INSTALLED"),rs.feeding and C.warn or(rs.configured and C.good or C.dim))
 put(e,2,e.h-5,"FLUX NETWORKS",C.dim);put(e,16,e.h-5,tostring(#fx),#fx>0 and C.good or C.warn)
 local sys=(#ss>0 and(en.online~=false)and"SYSTEMS NOMINAL"or"CHECK TELEMETRY");put(e,e.w-#sys-2,e.h-5,sys,sys=="SYSTEMS NOMINAL"and C.good or C.warn)
end

local function drawSensors(e,env)
 clearBody(e);local en,weather=environment(env);put(e,2,5,"ENVIRONMENT",C.dim);put(e,14,5,weather,weather=="THUNDER"and C.bad or(weather=="RAINING"and C.warn or C.good))
 put(e,2,6,"BIOME "..nice(en.biome or"UNKNOWN").."   DIM "..nice(en.dimension or"UNKNOWN"),C.text)
 put(e,2,7,"MOON "..nice(en.moon or"UNKNOWN").."   LIGHT "..tostring(en.blockLight or"?").." / SKY "..tostring(en.skyLight or"?"),C.dim)
 rule(e,8)
 local ss=allSensors(env);put(e,2,9,"DETECTED SENSORS "..#ss,#ss>0 and C.good or C.warn)
 if #ss==0 then center(e,13,"NO SENSOR TELEMETRY",C.warn);return end
 local x1,x2=2,math.floor(e.w/2)+1;local y=11;local right=false;local maxY=e.h-4
 for i,s in ipairs(ss)do
  if y+1>maxY then if not right then right=true;y=11 else break end end
  local x=right and x2 or x1;local source=s._source and(" @"..tostring(s._source))or""
  put(e,x,y,nice(s.reportedName or s.name or s.type or("SENSOR "..i))..source,C.text)
  put(e,x,y+1,metricLine(s),C.good)
  y=y+2
 end
 local capacity=math.max(1,math.floor((maxY-10)/2))*2
 if #ss>capacity then put(e,e.w-16,e.h-4,"+"..tostring(#ss-capacity).." MORE",C.warn)end
end

local function drawPowerSide(e,env)
 pcall(e.mon.setTextScale,e.scale);e.mon.setBackgroundColor(C.bg);e.mon.setTextColor(C.text);e.mon.clear()
 put(e,2,1,"POWER",C.text);put(e,math.max(2,e.w-6),1,gameTime(),C.dim);rule(e,3)
 local raw=state(env).power or{};local rs=state(env).power_reserve or{};local main=chooseMainMatrix(raw,rs);local mp=percent(main)
 center(e,5,"MAIN MATRIX",C.dim);center(e,6,mp and string.format("%.1f%%",mp)or"NO MATRIX",mp and C.good or C.warn)
 local x1=math.floor(e.w/2)-3;local x2=x1+6;local y1=8;local y2=15;fill(e,x1,y1,x2,y2,C.panel);fill(e,x1+1,y1+1,x2-1,y2-1,C.bg)
 local ih=y2-y1-1;local rows=mp and math.floor(ih*mp/100+.5)or 0;if rows>0 then fill(e,x1+1,y2-rows,x2-1,y2-1,C.good)end
 center(e,16,powerStatus(main),C.text)
 put(e,2,17,"STORED "..fmt(main and main.stored).." FE",C.text);put(e,2,18,"IN  +"..fmt(main and main.input).." FE/t",C.good);put(e,2,19,"OUT -"..fmt(main and main.output).." FE/t",C.dim)
 rule(e,20)
 local rp=tonumber(rs.reservePercent);put(e,2,21,"RESERVE",C.dim);put(e,10,21,rp and string.format("%.1f%%",rp)or"--",rp and C.good or C.dim)
 put(e,2,22,upper(rs.status or"NOT INSTALLED"),rs.feeding and C.warn or(rs.configured and C.good or C.dim))
 local fx=flux(env);put(e,2,24,"FLUX NETWORKS "..#fx,#fx>0 and C.good or C.warn)
 local y=25;for i,n in ipairs(fx)do if y>e.h then break end;put(e,2,y,nice(n.networkName or n.peripheral or("NETWORK "..i)),C.text);if y+1<=e.h then put(e,2,y+1,fmt(n.stored).." FE  NET "..fmt(n.net).."/t",C.dim)end;y=y+2 end
end

local function navView(e,x,y)
 if y<e.h-2 then return nil end
 local items={"home","doors","sensors"};local left,right,gap=2,e.w-1,1;local cell=math.floor((right-left+1-gap*2)/3)
 for i,v in ipairs(items)do local a=left+(i-1)*(cell+gap);local b=i==3 and right or a+cell-1;if x>=a and x<=b then return v end end
end

function M.init(c)cfg=c or{};view="home";lastEnv,lastMeta=nil,nil;return base.init(c)end
function M.render(env,meta)
 lastEnv,lastMeta=env,meta;local ok=base.render(env,meta);local mons=detectMonitors();local main=mons[1]
 if main then if view=="home"then drawHome(main,env)elseif view=="sensors"then drawSensors(main,env)end end
 if mons[2]then drawPowerSide(mons[2],env)end
 return ok
end
function M.handleEvent(ev,env,action)
 if ev[1]=="monitor_touch"then
  local mons=detectMonitors();local main=mons[1];if main and ev[2]==main.name then local v=navView(main,tonumber(ev[3])or 0,tonumber(ev[4])or 0);if v then view=v end end
 end
 local handled=base.handleEvent and base.handleEvent(ev,env,action)or false
 if ev[1]=="monitor_touch"and lastEnv then M.render(lastEnv,lastMeta)end
 return handled
end
function M.onPeripheralChange(...)if base.onPeripheralChange then return base.onPeripheralChange(...)end end
return M
