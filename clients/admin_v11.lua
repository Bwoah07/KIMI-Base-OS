local M={}
local C={bg=colors.black,text=colors.white,dim=colors.lightGray,good=colors.lime,warn=colors.orange,bad=colors.red,panel=colors.gray,action=colors.blue}
local cfg,targets,lastEnv,lastMeta={}, {},nil,nil
local currentView="home"
local glyphs={["0"]={"111","101","101","101","111"},["1"]={"010","110","010","010","111"},["2"]={"111","001","111","100","111"},["3"]={"111","001","111","001","111"},["4"]={"101","101","111","001","001"},["5"]={"111","100","111","001","111"},["6"]={"111","100","111","101","111"},["7"]={"111","001","010","010","010"},["8"]={"111","101","111","101","111"},["9"]={"111","101","111","001","111"},[":"]={"0","1","0","1","0"}}

local function upper(v)return tostring(v or""):upper()end
local function nice(v)return upper(tostring(v or""):gsub("minecraft:",""):gsub("[_%-]"," "):gsub("(%l)(%u)","%1 %2"))end
local function gameTime()local ok,t=pcall(os.time,"ingame");t=ok and tonumber(t)or 0;local h=math.floor(t%24);local m=math.floor(((t%24)-h)*60+.5)%60;return string.format("%02d:%02d",h,m)end
local function fmtNumber(v)local n=tonumber(v);if not n then return"?"end;local a=math.abs(n);if a>=1e12 then return string.format("%.1fT",n/1e12)elseif a>=1e9 then return string.format("%.1fG",n/1e9)elseif a>=1e6 then return string.format("%.1fM",n/1e6)elseif a>=1e3 then return string.format("%.1fK",n/1e3)end;return tostring(math.floor(n+.5))end
local function fmtFE(v,rate)local s=fmtNumber(v);return s=="?"and"?"or s.." FE"..(rate and"/t"or"")end
local function baseName()local l=type(os.getComputerLabel)=="function"and os.getComputerLabel()or nil;if l and tostring(l):match("%S")and not tostring(l):match("^KIMI[%s%-]?%d+$")then return upper(l)end;return upper(cfg.name or"MAIN BASE")end
local function state(env)return env and env.state or{}end
local function doors(env)return state(env).doors and state(env).doors.doors or{}end
local function sensors(env)return state(env).attachments and state(env).attachments.sensors or{}end
local function fleet(env)local f=state(env).fleet or{};local total,online,current=0,0,0;local target=tostring(env and env.version or"");for _,m in pairs(f)do total=total+1;if m.online~=false then online=online+1;if tostring(m.version or"")==target then current=current+1 end end end;return f,total,online,current,target end
local function choosePower(raw)raw=raw or{};local best,score=raw,-1;local function use(p)if type(p)~="table"then return end;local cap=tonumber(p.capacity)or 0;local st=tonumber(p.stored)or 0;local s=(cap>0 and 1e9 or 0)+(st>0 and 1e7 or 0)+math.abs(tonumber(p.input)or 0)+math.abs(tonumber(p.output)or 0);if s>score then best,score=p,s end end;use(raw);for _,p in ipairs(raw.matrices or{})do use(p)end;for _,p in ipairs(raw.fluxNetworks or{})do use(p)end;return best or raw end
local function power(env)local raw=state(env).power or{};return raw,choosePower(raw)end
local function pct(p)local n=tonumber(p and p.filledPercentage);if n then if n<=1 then n=n*100 end;return math.max(0,math.min(100,n))end;local st,cap=tonumber(p and p.stored),tonumber(p and p.capacity);if st and cap and cap>0 then return math.max(0,math.min(100,st/cap*100))end end

local function isMonitor(n)local ok,t=pcall(peripheral.getType,n);if ok and t=="monitor"then return true end;if type(peripheral.hasType)=="function"then local ok2,v=pcall(peripheral.hasType,n,"monitor");if ok2 and v then return true end end;return false end
local function detectMonitors()local out={};local ok,names=pcall(peripheral.getNames);if not ok or type(names)~="table"then return out end;for _,n in ipairs(names)do if isMonitor(n)then local okW,m=pcall(peripheral.wrap,n);if okW and m then local scale=1;pcall(m.setTextScale,scale);local okS,w,h=pcall(m.getSize);if okS then w,h=tonumber(w),tonumber(h);if w<22 or h<12 then scale=.5;pcall(m.setTextScale,scale);local ok2,w2,h2=pcall(m.getSize);if ok2 then w,h=tonumber(w2)or w,tonumber(h2)or h end end;out[#out+1]={name=n,mon=m,w=w,h=h,scale=scale,area=w*h}end end end end;table.sort(out,function(a,b)if a.area~=b.area then return a.area>b.area end;if a.w~=b.w then return a.w>b.w end;return a.name<b.name end);return out end
local function prep(e)pcall(e.mon.setTextScale,e.scale);e.mon.setBackgroundColor(C.bg);e.mon.setTextColor(C.text);e.mon.clear();targets[e.name]={}end
local function put(e,x,y,text,fg,bg)if y<1 or y>e.h or x>e.w then return end;x=math.max(1,x);text=tostring(text or"");e.mon.setCursorPos(x,y);e.mon.setTextColor(fg or C.text);e.mon.setBackgroundColor(bg or C.bg);e.mon.write(text:sub(1,math.max(0,e.w-x+1)));e.mon.setBackgroundColor(C.bg)end
local function fill(e,x1,y1,x2,y2,bg)x1,x2=math.max(1,x1),math.min(e.w,x2);y1,y2=math.max(1,y1),math.min(e.h,y2);if x2<x1 or y2<y1 then return end;for y=y1,y2 do put(e,x1,y,string.rep(" ",x2-x1+1),C.text,bg)end end
local function center(e,y,text,fg,bg,x1,x2)x1,x2=x1 or 1,x2 or e.w;local w=x2-x1+1;text=tostring(text or"");if #text>w then text=text:sub(1,w)end;put(e,x1+math.max(0,math.floor((w-#text)/2)),y,text,fg,bg)end
local function rule(e,y)if y>=1 and y<=e.h then put(e,2,y,string.rep("-",math.max(0,e.w-2)),C.panel)end end
local function header(e,title)put(e,2,1,upper(title),C.text);put(e,math.max(2,e.w-6),1,gameTime(),C.dim);put(e,2,2,baseName(),C.dim);rule(e,3)end
local function reg(e,t)targets[e.name][#targets[e.name]+1]=t end
local function button(e,name,x1,y1,x2,y2,label,data,selected)x1,x2=math.max(2,x1),math.min(e.w-1,x2);fill(e,x1,y1,x2,y2,selected and C.action or C.panel);center(e,math.floor((y1+y2)/2),label,C.text,selected and C.action or C.panel,x1+1,x2-1);reg(e,{name=name,x1=x1,y1=y1,x2=x2,y2=y2,data=data})end
local function nav(e,view)if e.w<42 or e.h<16 then return end;local items={{"home","HOME"},{"doors","DOORS"},{"power","POWER"},{"sensors","SENSORS"},{"fleet","FLEET"}};local left,right,gap=2,e.w-1,1;local cell=math.floor((right-left+1-gap*4)/5);local y=e.h-2;for i,it in ipairs(items)do local x1=left+(i-1)*(cell+gap);local x2=i==5 and right or x1+cell-1;button(e,"nav",x1,y,x2,e.h,it[2],it[1],view==it[1])end end
local function bigClock(e,y,x1,x2)local value=gameTime();local scale=(x2-x1+1)>=42 and 2 or 1;local widths,total={},0;for i=1,#value do local ch=value:sub(i,i);widths[i]=(ch==":"and 1 or 3)*scale;total=total+widths[i]+(i<#value and 1 or 0)end;local x=x1+math.max(0,math.floor(((x2-x1+1)-total)/2));for i=1,#value do local ch=value:sub(i,i);local rows=glyphs[ch];local cols=ch==":"and 1 or 3;for r=1,5 do for c=1,cols do if rows[r]:sub(c,c)=="1"then fill(e,x+(c-1)*scale,y+r-1,x+c*scale-1,y+r-1,C.text)end end end;x=x+widths[i]+1 end end

local function renderDoorSummary(e,env,x1,x2,y1,y2)
 local ds=doors(env);put(e,x1,y1,"DOORS",C.dim);put(e,x1+6,y1,tostring(#ds),#ds>0 and C.good or C.dim)
 if #ds==0 then center(e,y1+3,"NO DOORS",C.dim,nil,x1,x2);return end
 local y=y1+2
 for _,d in ipairs(ds)do if y>y2 then break end;local n=upper(d.name or"DOOR");local st=d.online==false and"OFFLINE"or(d.open and"OPEN"or"CLOSED");put(e,x1,y,n,C.text);put(e,math.max(x1,x2-#st+1),y,st,d.online==false and C.bad or(d.open and C.good or C.dim));y=y+2 end
end
local function renderHome(e,env)
 prep(e);header(e,"COMMAND CENTER")
 local split=math.floor(e.w*.52);put(e,2,5,"BASE TIME",C.dim);bigClock(e,7,2,split-2);renderDoorSummary(e,env,split+2,e.w-2,5,e.h-8)
 rule(e,e.h-6);local ds=doors(env);local open=0;for _,d in ipairs(ds)do if d.open then open=open+1 end end;local status=#ds>0 and(tostring(open).." OPEN / "..tostring(#ds-open).." CLOSED")or"NO DOORS CONFIGURED";put(e,2,e.h-5,status,#ds>0 and C.good or C.dim);nav(e,"home")
end
local function verticalBattery(e,p)
 local pp=pct(p);local top=6;local bottom=math.max(top+6,e.h-9);local x1=4;local x2=e.w-3;if x2-x1<8 then x1=2;x2=e.w-1 end
 local capW=math.max(4,math.floor((x2-x1+1)*.4));local capX=x1+math.floor(((x2-x1+1)-capW)/2);fill(e,capX,top-1,capX+capW-1,top-1,C.panel)
 fill(e,x1,top,x2,bottom,C.panel);fill(e,x1+1,top+1,x2-1,bottom-1,C.bg)
 if pp then local innerH=math.max(1,bottom-top-1);local rows=math.floor(innerH*pp/100+.5);if rows>0 then fill(e,x1+1,bottom-rows,x2-1,bottom-1,C.good)end;center(e,math.floor((top+bottom)/2),string.format("%.0f%%",pp),C.text,nil,x1+1,x2-1)else center(e,math.floor((top+bottom)/2),"NO DATA",C.warn,nil,x1+1,x2-1)end
 return bottom
end
local function renderSidePower(e,env)
 local _,p=power(env);prep(e);header(e,"POWER");local b=verticalBattery(e,p);local y=b+2;if y<=e.h then center(e,y,fmtFE(p.stored,false),C.text,nil,2,e.w-1)end;if y+2<=e.h then put(e,2,y+2,"IN  +"..fmtFE(p.input,true),C.good)end;if y+3<=e.h then put(e,2,y+3,"OUT -"..fmtFE(p.output,true),C.warn)end
end
local function renderSideFleet(e,env)
 local f,total,online,current,target=fleet(env);prep(e);header(e,"FLEET");local locked=total>0 and online==total and current==total;center(e,5,locked and("LOCKED "..current.."/"..total)or("ONLINE "..online.."/"..total),locked and C.good or C.warn,nil,2,e.w-1);put(e,2,7,"VERSION",C.dim);put(e,2,8,tostring(env and env.version or"?"),C.text);put(e,2,10,"TARGET",C.dim);put(e,2,11,target,C.text);rule(e,13);local ids={};for id in pairs(f)do ids[#ids+1]=id end;table.sort(ids,function(a,b)return tostring(a)<tostring(b)end);local y=15;for _,id in ipairs(ids)do if y>e.h then break end;local m=f[id];local currentMachine=m.online~=false and tostring(m.version or"")==target;local st=m.online==false and"OFF"or(currentMachine and"CURRENT"or"UPDATE");put(e,2,y,upper(m.name or m.role or("PC "..id)),m.online==false and C.bad or C.good);put(e,math.max(2,e.w-#st-1),y,st,currentMachine and C.good or C.warn);y=y+2 end
end
local function renderDoors(e,env)prep(e);header(e,"DOORS");local ds=doors(env);put(e,2,5,"REGISTERED "..#ds,#ds>0 and C.good or C.dim);rule(e,7);local y=9;for _,d in ipairs(ds)do if y>e.h-4 then break end;local st=d.online==false and"OFFLINE"or(d.open and"OPEN"or"CLOSED");put(e,2,y,upper(d.name or"DOOR"),C.text);put(e,math.max(2,e.w-#st-1),y,st,d.online==false and C.bad or(d.open and C.good or C.dim));y=y+2 end;nav(e,"doors")end
local function renderPower(e,env)prep(e);header(e,"POWER");local _,p=power(env);local pp=pct(p);if not pp then center(e,10,"NO POWER DATA",C.warn,nil,2,e.w-1);nav(e,"power");return end;local split=math.floor(e.w*.45);local fake={name=e.name,mon=e.mon,w=split,h=e.h,scale=e.scale};verticalBattery(fake,p);put(e,split+3,7,"STORED",C.dim);put(e,split+3,8,fmtFE(p.stored,false),C.text);put(e,split+3,11,"CAPACITY",C.dim);put(e,split+3,12,fmtFE(p.capacity,false),C.text);put(e,split+3,15,"IN  +"..fmtFE(p.input,true),C.good);put(e,split+3,17,"OUT -"..fmtFE(p.output,true),C.warn);nav(e,"power")end
local function renderSensors(e,env)prep(e);header(e,"SENSORS");local ss=sensors(env);put(e,2,5,"ONLINE "..#ss,#ss>0 and C.good or C.warn);rule(e,7);local y=9;for _,s in ipairs(ss)do if y>e.h-4 then break end;put(e,2,y,nice(s.type or"SENSOR"),C.text);put(e,2,y+1,nice(s.summary or"ONLINE"),C.good);y=y+3 end;nav(e,"sensors")end
local function renderFleet(e,env)prep(e);header(e,"FLEET");local f,total,online,current,target=fleet(env);center(e,5,(current==total and total>0)and("LOCKED "..current.."/"..total)or("ONLINE "..online.."/"..total),current==total and C.good or C.warn,nil,2,e.w-1);put(e,2,7,"VERSION "..tostring(env and env.version or"?"),C.dim);rule(e,9);local ids={};for id in pairs(f)do ids[#ids+1]=id end;table.sort(ids,function(a,b)return tostring(a)<tostring(b)end);local y=11;for _,id in ipairs(ids)do if y>e.h-4 then break end;local m=f[id];local st=m.online==false and"OFFLINE"or(tostring(m.version or"")==target and"CURRENT"or"OUTDATED");put(e,2,y,upper(m.name or m.role or"PC"),m.online==false and C.bad or C.good);put(e,math.max(2,e.w-#st-1),y,st,st=="CURRENT"and C.good or C.warn);y=y+2 end;nav(e,"fleet")end
local mainViews={home=renderHome,doors=renderDoors,power=renderPower,sensors=renderSensors,fleet=renderFleet}
local function renderAll(env,meta)local mons=detectMonitors();if #mons==0 then return end;(mainViews[currentView]or renderHome)(mons[1],env);if mons[2]then renderSidePower(mons[2],env)end;if mons[3]then renderSideFleet(mons[3],env)end;for i=4,#mons do prep(mons[i]);header(mons[i],"SENSORS");local ss=sensors(env);center(mons[i],math.floor(mons[i].h/2),#ss.." ONLINE",#ss>0 and C.good or C.warn,nil,2,mons[i].w-1)end end
function M.init(c)cfg=c or{};currentView="home"end
function M.render(env,meta)lastEnv,lastMeta=env,meta;local ok,err=pcall(renderAll,env,meta);if not ok then return false,err end;return true end
function M.handleEvent(ev,env,action)if ev[1]~="monitor_touch"then return false end;local n,x,y=ev[2],tonumber(ev[3]),tonumber(ev[4]);for _,t in ipairs(targets[n]or{})do if x and y and x>=t.x1 and x<=t.x2 and y>=t.y1 and y<=t.y2 then if t.name=="nav"then currentView=t.data;renderAll(lastEnv,lastMeta);return true end end end;return false end
function M.onPeripheralChange()if lastEnv then renderAll(lastEnv,lastMeta)end end
return M
