local M = {}
local C={bg=colors.black,text=colors.white,dim=colors.lightGray,good=colors.lime,warn=colors.orange,bad=colors.red,panel=colors.gray,action=colors.blue,accent=colors.cyan or colors.lightBlue}
local cfg,monitors,lastEnv,lastMeta=nil,{},nil,nil
local targets,views={},{ }

local glyphs={
["0"]={"111","101","101","101","111"},["1"]={"010","110","010","010","111"},
["2"]={"111","001","111","100","111"},["3"]={"111","001","111","001","111"},
["4"]={"101","101","111","001","001"},["5"]={"111","100","111","001","111"},
["6"]={"111","100","111","101","111"},["7"]={"111","001","010","010","010"},
["8"]={"111","101","111","101","111"},["9"]={"111","101","111","001","111"},[":"]={"0","1","0","1","0"}}
local function upper(v)return tostring(v or ""):upper()end
local function nice(v)return upper(tostring(v or ""):gsub("minecraft:",""):gsub("[_%-]"," "):gsub("(%l)(%u)","%1 %2"))end
local function gameTime() local ok,t=pcall(os.time,"ingame");t=ok and tonumber(t)or 0;local h=math.floor(t%24);local m=math.floor(((t%24)-h)*60);return string.format("%02d:%02d",h,m)end
local function fmtNumber(v)local n=tonumber(v);if not n then return "?" end;local a=math.abs(n);if a>=1e15 then return string.format("%.1fP",n/1e15)elseif a>=1e12 then return string.format("%.1fT",n/1e12)elseif a>=1e9 then return string.format("%.1fG",n/1e9)elseif a>=1e6 then return string.format("%.1fM",n/1e6)elseif a>=1e3 then return string.format("%.1fK",n/1e3)end;return math.abs(n-math.floor(n))>.01 and string.format("%.2f",n)or tostring(math.floor(n))end
local function fmtFE(v,rate)local s=fmtNumber(v);return s=="?"and"?"or s.." FE"..(rate and "/t"or"")end
local function computerName()local l=type(os.getComputerLabel)=="function"and os.getComputerLabel()or nil;if l and tostring(l):match("%S")and not tostring(l):match("^KIMI[%s%-]?%d+$")then return upper(l)end;local n=cfg and cfg.name;if n and tostring(n):match("%S")and not tostring(n):match("^KIMI[%s%-]?%d+$")then return upper(n)end;return"MAIN BASE"end

local function detectMonitors()
 local out={};for _,name in ipairs(peripheral.getNames())do if peripheral.hasType(name,"monitor")then local mon=peripheral.wrap(name);if mon then local scale=1.0;pcall(mon.setTextScale,scale);local ok,w,h=pcall(mon.getSize);if ok and tonumber(w)and tonumber(h)then w,h=tonumber(w),tonumber(h);if w<22 or h<12 then scale=.5;pcall(mon.setTextScale,scale);local ok2,w2,h2=pcall(mon.getSize);if ok2 then w,h=tonumber(w2)or w,tonumber(h2)or h end end;out[#out+1]={name=name,mon=mon,w=w,h=h,scale=scale,area=w*h}end end end end;table.sort(out,function(a,b)if a.area~=b.area then return a.area>b.area elseif a.w~=b.w then return a.w>b.w else return a.name<b.name end end);return out
end
local function prep(e)pcall(e.mon.setTextScale,e.scale);e.mon.setBackgroundColor(C.bg);e.mon.setTextColor(C.text);e.mon.clear();targets[e.name]={}end
local function put(e,x,y,text,fg,bg)if y<1 or y>e.h or x>e.w then return end;x=math.max(1,x);text=tostring(text or"");e.mon.setCursorPos(x,y);e.mon.setTextColor(fg or C.text);e.mon.setBackgroundColor(bg or C.bg);e.mon.write(text:sub(1,math.max(0,e.w-x+1)));e.mon.setBackgroundColor(C.bg)end
local function fill(e,x1,y1,x2,y2,bg)x1,x2=math.max(1,x1),math.min(e.w,x2);y1,y2=math.max(1,y1),math.min(e.h,y2);if x2<x1 or y2<y1 then return end;for y=y1,y2 do put(e,x1,y,string.rep(" ",x2-x1+1),C.text,bg)end end
local function center(e,y,text,fg,bg,x1,x2)x1,x2=x1 or 1,x2 or e.w;local w=x2-x1+1;text=tostring(text or"");if #text>w then text=text:sub(1,w)end;put(e,x1+math.max(0,math.floor((w-#text)/2)),y,text,fg,bg)end
local function rule(e,y,x1,x2,color)x1,x2=x1 or 2,x2 or e.w-1;if y>=1 and y<=e.h and x2>=x1 then put(e,x1,y,string.rep("-",x2-x1+1),color or C.panel)end end
local function header(e,title)put(e,2,1,upper(title),C.text);put(e,math.max(2,e.w-6),1,gameTime(),C.dim);put(e,2,2,computerName(),C.dim);rule(e,3,1,e.w,C.panel)end
local function reg(e,t)targets[e.name][#targets[e.name]+1]=t end
local function button(e,name,x1,y1,x2,y2,label,data,selected)x1,x2=math.max(2,x1),math.min(e.w-1,x2);fill(e,x1,y1,x2,y2,selected and C.action or C.panel);center(e,math.floor((y1+y2)/2),label,C.text,selected and C.action or C.panel,x1+2,x2-2);reg(e,{name=name,x1=x1,y1=y1,x2=x2,y2=y2,data=data,label=label})end
local function drawBar(e,x1,y,x2,p,color)local w=x2-x1+1;local n=math.floor(w*math.max(0,math.min(100,tonumber(p)or 0))/100+.5);if n>0 then fill(e,x1,y,x1+n-1,y,color)end;if n<w then fill(e,x1+n,y,x2,y,C.panel)end end
local function bigClock(e,y,x1,x2)local value=gameTime();local scale=(x2-x1+1)>=42 and 2 or 1;local widths,total={},0;for i=1,#value do local ch=value:sub(i,i);widths[i]=(ch==":"and 1 or 3)*scale;total=total+widths[i]+(i<#value and 1 or 0)end;local x=x1+math.max(0,math.floor(((x2-x1+1)-total)/2));for i=1,#value do local ch=value:sub(i,i);local rows=glyphs[ch];local cols=ch==":"and 1 or 3;for r=1,5 do for c=1,cols do if rows[r]:sub(c,c)=="1"then fill(e,x+(c-1)*scale,y+r-1,x+c*scale-1,y+r-1,C.text)end end end;x=x+widths[i]+1 end end

local function state(env)return env and env.state or{}end
local function fleetStats(env)local f=state(env).fleet or{};local total,online,current=0,0,0;local target=tostring(env and env.version or"");for _,m in pairs(f)do total=total+1;if m.online~=false then online=online+1;if tostring(m.version or"")==target then current=current+1 end end end;return f,total,online,current,target end
local function sensors(env)return state(env).attachments and state(env).attachments.sensors or{}end
local function doors(env)return state(env).doors and state(env).doors.doors or{}end
local function choosePower(raw)raw=raw or{};local best,score=nil,-1;local function use(p)if type(p)~="table"then return end;local cap=tonumber(p.capacity)or 0;local st=tonumber(p.stored)or 0;local s=(cap>0 and 1e9 or 0)+(st>0 and 1e7 or 0)+math.abs(tonumber(p.input)or 0)+math.abs(tonumber(p.output)or 0);if s>score then best,score=p,s end end;for _,p in ipairs(raw.matrices or{})do use(p)end;for _,p in ipairs(raw.fluxNetworks or{})do use(p)end;for _,p in ipairs(raw.energyDetectors or{})do use(p)end;use(raw);return best or raw end
local function power(env)local raw=state(env).power or{};return raw,choosePower(raw)end
local function pct(p)local n=tonumber(p and p.filledPercentage);if n then if n<=1 then n=n*100 end;return math.max(0,math.min(100,n))end;local st,cap=tonumber(p and p.stored),tonumber(p and p.capacity);if st and cap and cap>0 then return math.max(0,math.min(100,st/cap*100))end end
local function fleetLocked(env)local _,t,o,c=fleetStats(env);return t>0 and t==o and t==c,t,o,c end
local function systemStatus(env)local locked=select(1,fleetLocked(env));local ss=sensors(env);if not locked then return"FLEET NEEDS ATTENTION",C.warn elseif #ss==0 then return"SENSOR BUS OFFLINE",C.warn else return"ALL SYSTEMS NOMINAL",C.good end end
local function sourceName(id,m)if m and m.name and not tostring(m.name):match("^KIMI[%s%-]?%d+$")then return upper(m.name)end;if tostring(id)=="server"or(m and m.role=="server")then return"MAIN BASE"elseif m and m.role=="node"then return"REMOTE NODE"else return"ROOM PANEL"end end

local function nav(e,view)if e.w<42 or e.h<16 then return end;local items={{"home","HOME"},{"doors","DOORS"},{"power","POWER"},{"sensors","SENSORS"},{"fleet","FLEET"}};local left,right,gap=2,e.w-1,1;local cell=math.floor((right-left+1-gap*4)/5);local y=e.h-2;for i,it in ipairs(items)do local x1=left+(i-1)*(cell+gap);local x2=i==5 and right or x1+cell-1;button(e,"nav_"..it[1],x1,y,x2,e.h,it[2],it[1],view==it[1])end end

local function renderHome(e,env)
 prep(e);header(e,"COMMAND CENTER");local locked,total,online,current=fleetLocked(env);local ds,ss=doors(env),sensors(env);local raw,p=power(env);local pp=pct(p);local status,color=systemStatus(env)
 put(e,2,5,"FLEET",C.dim);put(e,8,5,tostring(online).."/"..tostring(total),locked and C.good or C.warn);put(e,16,5,"DOORS",C.dim);put(e,22,5,tostring(#ds),#ds>0 and C.good or C.dim);put(e,28,5,"SENS",C.dim);put(e,33,5,tostring(#ss),#ss>0 and C.good or C.warn);if e.w>43 then put(e,e.w-14,5,"POWER",C.dim);put(e,e.w-7,5,pp and string.format("%.0f%%",pp)or"N/A",pp and C.good or C.dim)end
 rule(e,7);local split=math.floor(e.w*.54);put(e,2,9,"BASE TIME",C.dim);bigClock(e,11,2,split-2);put(e,split+1,9,"POWER",C.dim);if pp then put(e,split+1,11,string.format("%.1f%%",pp),pp>=50 and C.good or C.warn);drawBar(e,split+1,13,e.w-2,pp,pp>=50 and C.good or C.warn);put(e,split+1,15,"IN   +"..fmtFE(p.input,true),C.good);put(e,split+1,16,"OUT  -"..fmtFE(p.output,true),C.warn);put(e,split+1,18,"STORED "..fmtFE(p.stored,false),C.text)else put(e,split+1,12,"NO POWER DATA",C.dim)end
 rule(e,e.h-6);put(e,2,e.h-5,status,color);put(e,2,e.h-4,"VERSION "..tostring(env and env.version or"?"),C.dim);nav(e,"home")
end
local function renderPower(e,env)
 prep(e);header(e,"POWER");local raw,p=power(env);local pp=pct(p);if tonumber(raw.onlineSources or 0)<=0 then center(e,math.floor(e.h/2),"NO POWER TELEMETRY",C.dim,nil,2,e.w-1);nav(e,"power");return end
 center(e,6,pp and string.format("%.1f%%",pp)or"ONLINE",pp and C.good or C.text,nil,2,e.w-1);if pp then drawBar(e,3,8,e.w-2,pp,pp>=50 and C.good or C.warn)end;put(e,2,11,"STORED",C.dim);put(e,2,12,fmtFE(p.stored,false),C.text);put(e,math.floor(e.w/2),11,"CAPACITY",C.dim);put(e,math.floor(e.w/2),12,fmtFE(p.capacity,false),C.text);put(e,2,15,"INPUT",C.dim);put(e,2,16,"+"..fmtFE(p.input,true),C.good);put(e,math.floor(e.w/2),15,"OUTPUT",C.dim);put(e,math.floor(e.w/2),16,"-"..fmtFE(p.output,true),C.warn);rule(e,19);put(e,2,21,"SOURCES  "..tostring(raw.onlineSources or 0),C.dim);nav(e,"power")
end
local function renderFleet(e,env)
 prep(e);header(e,"FLEET");local f,total,online,current,target=fleetStats(env);local locked=total>0 and total==online and total==current;center(e,5,locked and("LOCKED  "..current.."/"..total)or("ONLINE  "..online.."/"..total),locked and C.good or C.warn,nil,2,e.w-1);put(e,2,7,"TARGET  "..target,C.dim);rule(e,9);local ids={};for id in pairs(f)do ids[#ids+1]=id end;table.sort(ids,function(a,b)return tonumber(a or 0)<tonumber(b or 0)end);local y=11;for _,id in ipairs(ids)do if y>e.h-4 then break end;local m=f[id];put(e,2,y,sourceName(id,m),m.online==false and C.bad or C.good);put(e,2,y+1,tostring(m.version or"UNKNOWN").."  "..upper(m.updateStatus or""),C.dim);y=y+3 end;nav(e,"fleet")
end
local function renderSensors(e,env)
 prep(e);header(e,"SENSORS");local ss=sensors(env);put(e,2,5,"ONLINE  "..#ss,#ss>0 and C.good or C.warn);rule(e,7);if #ss==0 then center(e,11,"NO DETECTOR TELEMETRY",C.warn,nil,2,e.w-1);center(e,13,"WIRE DETECTORS TO A KIMI COMPUTER",C.dim,nil,2,e.w-1);nav(e,"sensors");return end;local y=9;for _,s in ipairs(ss)do if y>e.h-4 then break end;put(e,2,y,nice(s.type or"SENSOR"),C.text);put(e,2,y+1,nice(s.summary or"ONLINE"),C.good);y=y+3 end;nav(e,"sensors")
end
local function renderDoors(e,env)
 prep(e);header(e,"DOORS");local ds=doors(env);put(e,2,5,"REGISTERED  "..#ds,#ds>0 and C.good or C.dim);rule(e,7);if #ds==0 then center(e,11,"NO DOORS REGISTERED",C.dim,nil,2,e.w-1);center(e,13,"SET UP EACH DOOR ON ITS ROOM PANEL",C.dim,nil,2,e.w-1);nav(e,"doors");return end;local y=9;for _,d in ipairs(ds)do if y>e.h-4 then break end;put(e,2,y,upper(d.name or"DOOR"),C.text);put(e,2,y+1,d.online==false and"OFFLINE"or(d.open and"OPEN"or"CLOSED"),d.online==false and C.bad or(d.open and C.good or C.dim));y=y+3 end;nav(e,"doors")
end
local renderers={home=renderHome,power=renderPower,fleet=renderFleet,sensors=renderSensors,doors=renderDoors}
local function sideView(index,env)if index==2 then local raw=state(env).power or{};if tonumber(raw.onlineSources or 0)>0 then return"power"else return"fleet"end elseif index==3 then return"fleet"elseif index==4 then return #sensors(env)>0 and"sensors"or"doors"else return"fleet"end end
local function renderAll(env,meta)monitors=detectMonitors();for i,e in ipairs(monitors)do local view=i==1 and(views[e.name]or"home")or sideView(i,env);(renderers[view]or renderHome)(e,env,meta)end end
function M.init(newCfg)cfg=newCfg or{};monitors=detectMonitors()end
function M.onPeripheralChange()monitors=detectMonitors();if lastEnv then renderAll(lastEnv,lastMeta)end end
function M.render(env,meta)lastEnv,lastMeta=env,meta;renderAll(env,meta)end
function M.handleEvent(ev,env,action)
 if ev[1]~="monitor_touch"then return false end;local name,x,y=ev[2],tonumber(ev[3]),tonumber(ev[4]);if not name or not x or not y then return false end
 for _,t in ipairs(targets[name]or{})do if x>=t.x1 and x<=t.x2 and y>=t.y1 and y<=t.y2 then if t.name:sub(1,4)=="nav_"then views[name]=t.data;renderAll(env,lastMeta);return true end end end;return false
end
return M
