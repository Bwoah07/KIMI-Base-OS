local base=require("clients.admin_v18")
local M={}
for k,v in pairs(base)do M[k]=v end

local cfg={};local lastEnv,lastMeta;local animFrame=0;local animTimer=nil;local identifyTargets={};local identifyStatus=""
local C={bg=colors.black,text=colors.white,dim=colors.lightGray,good=colors.lime,warn=colors.orange,bad=colors.red,panel=colors.gray,accent=colors.cyan or colors.lightBlue,sky=colors.lightBlue}
local function upper(v)return tostring(v or""):upper()end
local function nice(v)return upper(tostring(v or""):gsub("minecraft:",""):gsub("[_%-]"," "):gsub("(%l)(%u)","%1 %2"))end
local function state(env)return env and env.state or{}end
local function gameTime()local ok,t=pcall(os.time,"ingame");t=ok and tonumber(t)or 0;local h=math.floor(t%24);local m=math.floor(((t%24)-h)*60+.5)%60;return string.format("%02d:%02d",h,m),h end
local function fmt(n)local v=tonumber(n);if not v then return"?"end;local a=math.abs(v);if a>=1e15 then return string.format("%.1fP",v/1e15)elseif a>=1e12 then return string.format("%.1fT",v/1e12)elseif a>=1e9 then return string.format("%.1fG",v/1e9)elseif a>=1e6 then return string.format("%.1fM",v/1e6)elseif a>=1e3 then return string.format("%.1fK",v/1e3)end;return tostring(math.floor(v+.5))end
local function duration(s)s=tonumber(s);if not s or s<0 or s~=s then return"CALCULATING"end;s=math.floor(s+.5);if s<60 then return s.."s"end;local m=math.floor(s/60);if m<60 then return string.format("%dm %02ds",m,s%60)end;local h=math.floor(m/60);if h<24 then return string.format("%dh %02dm",h,m%60)end;return string.format("%dd %02dh",math.floor(h/24),h%24)end
local function isMonitor(n)local ok,t=pcall(peripheral.getType,n);if ok and t=="monitor"then return true end;if type(peripheral.hasType)=="function"then local ok2,v=pcall(peripheral.hasType,n,"monitor");if ok2 and v then return true end end;return false end
local function detectMonitors()local out={};local ok,names=pcall(peripheral.getNames);if not ok or type(names)~="table"then return out end;for _,n in ipairs(names)do if isMonitor(n)then local okW,m=pcall(peripheral.wrap,n);if okW and m then local scale=1;pcall(m.setTextScale,scale);local okS,w,h=pcall(m.getSize);if okS then w,h=tonumber(w),tonumber(h);if w<22 or h<12 then scale=.5;pcall(m.setTextScale,scale);local ok2,w2,h2=pcall(m.getSize);if ok2 then w,h=tonumber(w2)or w,tonumber(h2)or h end end;out[#out+1]={name=n,mon=m,w=w,h=h,scale=scale,area=w*h}end end end end;table.sort(out,function(a,b)if a.area~=b.area then return a.area>b.area end;if a.w~=b.w then return a.w>b.w end;return a.name<b.name end);return out end
local function prep(e)pcall(e.mon.setTextScale,e.scale);e.mon.setBackgroundColor(C.bg);e.mon.setTextColor(C.text);e.mon.clear()end
local function put(e,x,y,text,fg,bg)if not e or y<1 or y>e.h or x>e.w then return end;x=math.max(1,x);text=tostring(text or"");e.mon.setCursorPos(x,y);e.mon.setTextColor(fg or C.text);e.mon.setBackgroundColor(bg or C.bg);e.mon.write(text:sub(1,math.max(0,e.w-x+1)));e.mon.setBackgroundColor(C.bg)end
local function fill(e,x1,y1,x2,y2,bg)x1,x2=math.max(1,x1),math.min(e.w,x2);y1,y2=math.max(1,y1),math.min(e.h,y2);if x2<x1 or y2<y1 then return end;for y=y1,y2 do put(e,x1,y,string.rep(" ",x2-x1+1),C.text,bg)end end
local function center(e,y,text,fg,bg,x1,x2)x1=x1 or 1;x2=x2 or e.w;local w=x2-x1+1;text=tostring(text or"");if #text>w then text=text:sub(1,w)end;put(e,x1+math.max(0,math.floor((w-#text)/2)),y,text,fg,bg)end
local function rule(e,y)put(e,2,y,string.rep("-",math.max(0,e.w-2)),C.panel)end
local function header(e,title)local tm=gameTime();put(e,2,1,title,C.text);put(e,math.max(2,e.w-#tm-1),1,tm,C.dim);put(e,2,2,upper((type(os.getComputerLabel)=="function"and os.getComputerLabel())or cfg.name or"KIMI"),C.dim);rule(e,3)end
local function hasCategory(d,w)for _,c in ipairs(d and d.categories or{})do if c==w then return true end end;return false end
local function sensors(env)local a=state(env).attachments or{};local out,seen={},{};for _,d in ipairs(a.sensors or{})do local k=tostring(d._source or"").."|"..tostring(d.name or d.type);if not seen[k]then seen[k]=true;out[#out+1]=d end end;for _,d in ipairs(a.devices or{})do if hasCategory(d,"sensor")or hasCategory(d,"sensor_candidate")then local k=tostring(d._source or"").."|"..tostring(d.name or d.type);if not seen[k]then seen[k]=true;out[#out+1]=d end end end;table.sort(out,function(a,b)return tostring(a.reportedName or a.name or a.type)<tostring(b.reportedName or b.name or b.type)end);return out end

local function weatherArt(e,en,frame)
 if not e then return end;local x1=math.max(2,math.floor(e.w*.56));local x2=e.w-2;local y1=5;local y2=math.min(e.h-1,y1+7);if x2-x1<8 then return end;fill(e,x1,y1,x2,y2,C.bg)
 local w=upper(en.weather or"");local _,hour=gameTime();local night=hour<6 or hour>=18
 if w:find("THUNDER",1,true)then
  center(e,y1,"~~~~ CLOUD ~~~~",C.dim,nil,x1,x2)
  for r=2,6 do local off=(frame+r)%3;put(e,x1+off*3,y1+r,string.rep("  | ",math.max(1,math.floor((x2-x1)/4))),C.sky)end
  if frame%6<=1 then center(e,y1+2,"  \\  /",colors.yellow,nil,x1,x2);center(e,y1+3,"   \\/ ",colors.yellow,nil,x1,x2);center(e,y1+4,"    /  ",colors.white,nil,x1,x2)end
 elseif w:find("RAIN",1,true)then
  center(e,y1,"~~~~ CLOUD ~~~~",C.dim,nil,x1,x2)
  for r=2,6 do local s=((frame+r)%2==0)and" /   /   /   /"or"   /   /   /";put(e,x1,y1+r,s,C.sky)end
 elseif night then
  put(e,x1,y1,frame%2==0 and"*     .      *"or"   .     *    .",C.text);center(e,y1+2,"  ((  ",colors.yellow,nil,x1,x2);center(e,y1+3," (    ",colors.yellow,nil,x1,x2);center(e,y1+4,"  ((  ",colors.yellow,nil,x1,x2);put(e,x1,y1+6,frame%2==0 and" .   *    ."or" *     .    *",C.text)
 else
  local rays=frame%2==0 and"\\  |  /"or" --+-- ";center(e,y1,rays,colors.yellow,nil,x1,x2);center(e,y1+1,"  \\|/  ",colors.yellow,nil,x1,x2);center(e,y1+2,"-- O --",colors.yellow,nil,x1,x2);center(e,y1+3,"  /|\\  ",colors.yellow,nil,x1,x2);center(e,y1+4,rays,colors.yellow,nil,x1,x2)
 end
end
local function renderEnvironment(e,env)
 prep(e);header(e,"ENVIRONMENT / WEATHER");local en=state(env).environment or{};local w=upper(en.weather or"UNKNOWN");put(e,2,5,"WEATHER",C.dim);put(e,2,6,w,w:find("THUNDER",1,true)and C.bad or(w:find("RAIN",1,true)and C.warn or C.good));put(e,2,8,"BIOME",C.dim);put(e,2,9,nice(en.biome or"UNKNOWN"),C.text);put(e,2,11,"DIMENSION",C.dim);put(e,2,12,nice(en.dimension or"UNKNOWN"),C.text);if e.h>=15 then put(e,2,14,"MOON",C.dim);put(e,2,15,nice(en.moon or"UNKNOWN"),C.text)end;if e.h>=17 then put(e,2,17,"LIGHT "..tostring(en.blockLight or"?").." / SKY "..tostring(en.skyLight or"?"),C.dim)end;weatherArt(e,en,animFrame)
end

local function renderAE(e,env)
 prep(e);header(e,"AE2 NETWORK");local a=state(env).ae2 or{};local online=a.online==true or a._status=="online";put(e,2,5,online and"ONLINE"or upper(a._status or"OFFLINE"),online and C.good or C.warn);if a.bridge then put(e,2,6,nice(a.bridge),C.dim)end
 local y=8;put(e,2,y,"ITEMS",C.dim);put(e,2,y+1,fmt(a.itemCount or a.items).." / "..fmt(a.itemTypes).." TYPES",C.text);y=y+4;put(e,2,y,"STORAGE",C.dim);put(e,2,y+1,fmt(a.usedItemStorage).." / "..fmt(a.totalItemStorage),C.text);y=y+4;put(e,2,y,"AE ENERGY",C.dim);put(e,2,y+1,fmt(a.storedEnergy).." / "..fmt(a.energyCapacity),C.text);if y+2<=e.h then put(e,2,y+2,"USE "..fmt(a.energyUsage).."  IN "..fmt(a.avgPowerInjection),C.dim)end;y=y+5;if y<=e.h then put(e,2,y,"CRAFT JOBS "..fmt(a.craftingJobs),(tonumber(a.craftingJobs) or 0)>0 and C.warn or C.good)end
end

local function renderBuilder(e,b,index,total)
 prep(e);header(e,"BUILDER / QUARRY");if not b then center(e,7,"NO BUILDER DETECTED",C.dim);return end
 put(e,2,5,nice(b.peripheral or b.type or"BUILDER").."  "..index.."/"..total,C.text);if b._source then put(e,2,6,"NODE "..tostring(b._source),C.dim)end
 local st=b.status or(b.running==true and"RUNNING"or(b.running==false and"IDLE"or"CONNECTED"));put(e,2,8,upper(st),b.running==false and C.warn or C.good)
 local p=tonumber(b.progress);if p then put(e,2,10,string.format("PROGRESS %.1f%%",p),C.text);fill(e,2,11,e.w-2,11,C.panel);local n=math.floor((e.w-3)*math.max(0,math.min(100,p))/100+.5);if n>0 then fill(e,2,11,1+n,11,C.good)end else put(e,2,10,b.apiLimited and"PROGRESS API LIMITED"or"PROGRESS CALCULATING",C.warn)end
 local y=13;if b.processed or b.total then put(e,2,y,"DONE "..fmt(b.processed).." / "..fmt(b.total),C.text);y=y+2 end;if b.remaining then put(e,2,y,"REMAIN "..fmt(b.remaining),C.dim);y=y+2 end;if b.rate then put(e,2,y,string.format("RATE %.2f blocks/s",b.rate),C.good);y=y+2 end;if b.currentY then put(e,2,y,"CURRENT Y "..tostring(b.currentY),C.dim);y=y+2 end;if b.energy then put(e,2,y,"ENERGY "..fmt(b.energy).." / "..fmt(b.energyCapacity),C.dim);y=y+2 end;if y<=e.h then put(e,2,y,"ETA "..duration(b.etaSeconds),b.etaSeconds and C.good or C.dim)end
end

local function metricRows(s)local m=s and s.metrics or{};local r={};local function add(k,v)if v~=nil then r[#r+1]={k,tostring(v)}end end;add("TEMP",m.temperature);add("HUMIDITY",m.humidity);add("PRESSURE",m.pressure);if m.radiationRaw~=nil then add("RADIATION",m.radiationRaw)elseif m.radiationText~=nil then add("RADIATION",m.radiationText)end;add("PLAYERS",m.onlinePlayers or m.playerCount);add("ENTITIES",m.entityCount);add("BLOCK LIGHT",m.blockLight);add("SKY LIGHT",m.skyLight);return r end
local function renderSensor(e,s,index,total)
 prep(e);header(e,"SENSOR "..index.."/"..total);if not s then center(e,7,"NO SENSOR",C.dim);return end;put(e,2,5,nice(s.reportedName or s.name or s.type or"SENSOR"),C.text);if s._source then put(e,2,6,"NODE "..tostring(s._source),C.dim)end;rule(e,8);put(e,2,10,nice(s.summary or"ONLINE"),C.good);local rows=metricRows(s);local y=12;for _,r in ipairs(rows)do if y+1>e.h then break end;put(e,2,y,r[1],C.dim);put(e,2,y+1,r[2],C.text);y=y+3 end;if y<=e.h and #rows==0 then put(e,2,y,"METHODS "..tostring(s.methodCount or 0),C.dim)end
end
local function renderSystem(e,env)
 prep(e);header(e,"KIMI SYSTEM");local st=state(env);local f=st.fleet or{};local total,online,stale=0,0,0;for _,m in pairs(f)do total=total+1;local age=tonumber(m.ageMs)or(os.epoch("utc")-(tonumber(m.lastSeen) or 0));if age<=10000 then online=online+1 elseif age<=45000 then stale=stale+1 end end;center(e,6,"SYSTEMS NOMINAL",C.good);put(e,2,9,"VERSION",C.dim);put(e,2,10,tostring(env and env.version or"?"),C.text);put(e,2,13,"FLEET "..online.." ONLINE",C.good);put(e,2,15,"STALE "..stale.." / TOTAL "..total,C.dim);put(e,2,18,"SENSORS "..#sensors(env),C.dim)
end

local function removeAt(t,i)local v=t[i];table.remove(t,i);return v end
local function planExtras(mons)
 local extras={};for i=4,#mons do extras[#extras+1]=mons[i]end;if #extras==0 then return nil,{} end
 local bi,bs=1,-1;for i,e in ipairs(extras)do local score=(e.w/math.max(1,e.h))*1000+e.area;if score>bs then bi,bs=i,score end end;local envMon=removeAt(extras,bi);return envMon,extras
end
local function renderFleet(e,env)
 prep(e);identifyTargets[e.name]={};header(e,"FLEET / IDENTIFY");local f=state(env).fleet or{};local ids={};for id in pairs(f)do ids[#ids+1]=id end;table.sort(ids,function(a,b)local na,nb=tonumber(a),tonumber(b);if na and nb then return na<nb end;return tostring(a)<tostring(b)end);put(e,2,5,"TOUCH A ROW TO IDENTIFY",C.dim);if identifyStatus~=""then put(e,2,6,identifyStatus,C.warn)end;local y=8;local now=os.epoch("utc");for _,id in ipairs(ids)do if y+1>e.h then break end;local m=f[id];local age=tonumber(m.ageMs)or(now-(tonumber(m.lastSeen) or 0));local st=age<=10000 and"ONLINE"or(age<=45000 and"STALE"or"OFFLINE");local fg=st=="ONLINE"and C.good or(st=="STALE"and C.warn or C.bad);local label="ID "..tostring(id).." "..upper(m.name or m.role or"KIMI");put(e,2,y,label,C.text);put(e,math.max(2,e.w-#st-1),y,st,fg);put(e,2,y+1,upper(m.role or"?").."  "..tostring(m.version or"?"),C.dim);identifyTargets[e.name][#identifyTargets[e.name]+1]={y1=y,y2=y+1,id=tonumber(id)or id};y=y+3 end
end

local function applyPlanner(env)
 local mons=detectMonitors();if #mons<1 then return mons end;if mons[3]then renderFleet(mons[3],env)end
 local envMon,extras=planExtras(mons);if envMon then renderEnvironment(envMon,env)end
 local st=state(env);local ae=st.ae2 or{};local bs=st.builder and st.builder.builders or{};local ss=sensors(env)
 if #extras>0 and (ae.bridge or ae.online==true or ae.connected==true)then renderAE(removeAt(extras,1),env)end
 if #extras>0 and #bs>0 then local ix=(math.floor(os.epoch("utc")/8000)%#bs)+1;renderBuilder(removeAt(extras,1),bs[ix],ix,#bs)end
 local page=math.floor(os.epoch("utc")/8000);for i,e in ipairs(extras)do if #ss>0 then local ix=((page+i-2)%#ss)+1;renderSensor(e,ss[ix],ix,#ss)else renderSystem(e,env)end end
 return mons,envMon
end
local function currentEnvironmentMonitor()local mons=detectMonitors();local em=select(1,planExtras(mons));return em end

function M.init(c)cfg=c or{};identifyTargets={};identifyStatus="";animFrame=0;if animTimer and type(os.cancelTimer)=="function"then pcall(os.cancelTimer,animTimer)end;animTimer=os.startTimer(.30);return base.init(c)end
function M.render(env,meta)lastEnv,lastMeta=env,meta;local ok=base.render(env,meta);applyPlanner(env);return ok end
function M.onPeripheralChange(...)identifyTargets={};if base.onPeripheralChange then return base.onPeripheralChange(...)end end
function M.handleEvent(ev,env,action)
 lastEnv=env or lastEnv
 if ev[1]=="timer"and animTimer and ev[2]==animTimer then animFrame=(animFrame+1)%1000;local em=currentEnvironmentMonitor();if em then weatherArt(em,state(lastEnv or{}).environment or{},animFrame)end;animTimer=os.startTimer(.30);return true end
 if ev[1]=="monitor_touch"then local name,y=ev[2],tonumber(ev[4]);for _,t in ipairs(identifyTargets[name]or{})do if y and y>=t.y1 and y<=t.y2 then local ok,res=pcall(action,"server","identify",{id=t.id,duration=8});identifyStatus=(ok and type(res)=="table"and res.ok~=false)and("IDENTIFY SENT -> "..tostring(t.id))or("IDENTIFY FAILED -> "..tostring(t.id));M.render(lastEnv,lastMeta);return true end end end
 local handled=base.handleEvent and base.handleEvent(ev,env,action)or false;if ev[1]=="monitor_touch"then M.render(lastEnv,lastMeta)end;return handled
end
return M
