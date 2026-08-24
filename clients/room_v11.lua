local M={}
local C={bg=colors.black,text=colors.white,dim=colors.lightGray,good=colors.lime,warn=colors.orange,bad=colors.red,action=colors.blue,panel=colors.gray}
local cfg,targets,lastEnv,lastMeta=nil,{},nil,nil

local function upper(v)return tostring(v or""):upper()end
local function nice(v)return upper(tostring(v or""):gsub("minecraft:",""):gsub("[_%-]"," "):gsub("(%l)(%u)","%1 %2"))end
local function gameTime()local ok,t=pcall(os.time,"ingame");t=ok and tonumber(t)or 0;local h=math.floor(t%24);local m=math.floor(((t%24)-h)*60);return string.format("%02d:%02d",h,m)end
local function computerName()local l=type(os.getComputerLabel)=="function"and os.getComputerLabel()or nil;if l and tostring(l):match("%S")and not tostring(l):match("^KIMI[%s%-]?%d+$")then return upper(l)end;local n=cfg and cfg.name;if n and tostring(n):match("%S")and not tostring(n):match("^KIMI[%s%-]?%d+$")then return upper(n)end;return"ROOM PANEL"end

local function isMonitor(name)
 local ok,t=pcall(peripheral.getType,name);if not ok then return false end
 if t=="monitor"then return true end
 if type(t)=="table"then for _,v in ipairs(t)do if v=="monitor"then return true end end end
 if type(peripheral.hasType)=="function"then local ok2,v=pcall(peripheral.hasType,name,"monitor");return ok2 and v==true end
 return false
end
local function detectMonitors()
 local out={};local ok,names=pcall(peripheral.getNames);if not ok or type(names)~="table"then return out end
 for _,name in ipairs(names)do if isMonitor(name)then local okWrap,mon=pcall(peripheral.wrap,name);if okWrap and mon then
  local scale=1.0;pcall(mon.setTextScale,scale);local okSize,w,h=pcall(mon.getSize)
  if okSize and tonumber(w)and tonumber(h)then w,h=tonumber(w),tonumber(h);if w<22 or h<12 then scale=.5;pcall(mon.setTextScale,scale);local ok2,w2,h2=pcall(mon.getSize);if ok2 then w,h=tonumber(w2)or w,tonumber(h2)or h end end;out[#out+1]={name=name,mon=mon,w=w,h=h,scale=scale,area=w*h}end
 end end end
 table.sort(out,function(a,b)if a.area~=b.area then return a.area>b.area elseif a.w~=b.w then return a.w>b.w else return a.name<b.name end end);return out
end
local function put(e,x,y,text,fg,bg)if y<1 or y>e.h or x>e.w then return end;x=math.max(1,x);text=tostring(text or"");e.mon.setCursorPos(x,y);e.mon.setTextColor(fg or C.text);e.mon.setBackgroundColor(bg or C.bg);e.mon.write(text:sub(1,math.max(0,e.w-x+1)))end
local function fill(e,x1,y1,x2,y2,bg)x1,x2=math.max(1,x1),math.min(e.w,x2);y1,y2=math.max(1,y1),math.min(e.h,y2);if x2<x1 or y2<y1 then return end;for y=y1,y2 do put(e,x1,y,string.rep(" ",x2-x1+1),C.text,bg)end end
local function center(e,y,text,fg,bg,x1,x2)x1,x2=x1 or 1,x2 or e.w;local w=math.max(1,x2-x1+1);text=tostring(text or"");if #text>w then text=text:sub(1,w)end;put(e,x1+math.max(0,math.floor((w-#text)/2)),y,text,fg,bg)end
local function rule(e,y)if y>=1 and y<=e.h then put(e,1,y,string.rep("-",e.w),C.panel)end end
local function prep(e)pcall(e.mon.setTextScale,e.scale);e.mon.setBackgroundColor(C.bg);e.mon.setTextColor(C.text);e.mon.clear();targets[e.name]={}end
local function reg(e,t)targets[e.name][#targets[e.name]+1]=t end
local function button(e,name,x1,y1,x2,y2,label,data,bg)x1,x2=math.max(2,x1),math.min(e.w-1,x2);y1,y2=math.max(1,y1),math.min(e.h,y2);fill(e,x1,y1,x2,y2,bg or C.action);center(e,math.floor((y1+y2)/2),label,C.text,bg or C.action,x1+2,x2-2);reg(e,{name=name,x1=x1,y1=y1,x2=x2,y2=y2,data=data,label=label})end

local function localState(meta)return meta and meta.localState or{}end
local function localDoors(meta)return localState(meta).doors and localState(meta).doors.localDoors or{}end
local function candidateList(meta)
 local raw=localState(meta).doors and localState(meta).doors.candidates or{};local dedicated,fallback={},{}
 for _,c in ipairs(raw)do if c.localConfigured~=true then if tostring(c.target)=="computer"then fallback[#fallback+1]=c else dedicated[#dedicated+1]=c end end end
 return #dedicated>0 and dedicated or fallback
end
local function sensorInfo(meta,env)
 local a=localState(meta).attachments or{};local ls=a.sensors or{};if #ls>0 then return ls[1],#ls,"LOCAL"end
 local gs=env and env.state and env.state.attachments and env.state.attachments.sensors or{};if #gs>0 then return gs[1],#gs,"BASE"end
 return nil,0,"NONE"
end
local function sensorMetric(s)local m=s and s.metrics or{};local order={{"temperature","TEMP"},{"onlinePlayers","PLAYERS"},{"biome","BIOME"},{"dimension","DIMENSION"},{"humidity","HUMIDITY"},{"radiationRaw","RAD"}};for _,p in ipairs(order)do if m[p[1]]~=nil then return p[2],nice(m[p[1]])end end;return"STATUS",nice(s and s.summary or"ONLINE")end
local function sensorTitle(s)local t=nice(s and s.type or"SENSOR");if t:find("ENVIRONMENT",1,true)then return"ENVIRONMENT"end;if t:find("PLAYER",1,true)then return"PLAYER DETECTOR"end;if t:find("GEO",1,true)then return"GEO SCANNER"end;return t end

local function header(e,meta,env)
 put(e,2,1,computerName(),C.text);put(e,math.max(2,e.w-6),1,gameTime(),C.dim);rule(e,2)
 local _,n,scope=sensorInfo(meta,env);put(e,2,3,meta and meta.connected==false and"BASE OFFLINE"or"BASE ONLINE",meta and meta.connected==false and C.warn or C.good)
 if n>0 then local s=scope.." SENS "..n;put(e,math.max(2,e.w-#s-1),3,s,C.good)end
end
local function sensorStrip(e,meta,env)
 local y=e.h-3;rule(e,y);local s,n,scope=sensorInfo(meta,env)
 if s then local k,v=sensorMetric(s);put(e,2,y+1,scope.." "..sensorTitle(s),C.dim);put(e,2,y+2,k.."  "..v,C.good);if n>1 then put(e,math.max(2,e.w-8),y+1,"+"..(n-1).." MORE",C.dim)end
 else put(e,2,y+1,"SENSORS NONE",C.warn);put(e,2,y+2,"NO BASE SENSOR DATA",C.dim)end
end
local function renderDoor(e,env,meta)
 local ds=localDoors(meta);if #ds==0 then return false end;local d=ds[1];local mode=tostring(d.mode or"hold");local state=d.online==false and"OFFLINE"or(mode=="pulse"and"READY"or(d.open and"OPEN"or"CLOSED"));local sc=d.online==false and C.bad or(d.open and C.good or C.text)
 center(e,6,upper(d.name or"DOOR"),C.dim,nil,2,e.w-1);center(e,8,state,sc,nil,2,e.w-1);center(e,9,d.signal==true and"REDSTONE ON"or"REDSTONE OFF",d.signal==true and C.good or C.dim,nil,2,e.w-1)
 local label=mode=="pulse"and"TRIGGER DOOR"or(d.open and"CLOSE DOOR"or"OPEN DOOR");button(e,"door_toggle",3,11,e.w-2,14,label,{_source=tostring(os.getComputerID()),target=d.target,side=d.side,id=d.id},d.open and C.good or C.action)
 if e.h>=22 then button(e,"door_mode",3,16,math.min(e.w-2,18),16,"MODE "..upper(mode),{target=d.target,side=d.side,mode=mode},C.panel)end;sensorStrip(e,meta,env);return true
end
local function groups(list)local order,g={},{};for _,c in ipairs(list)do local k=tostring(c.target);if not g[k]then g[k]={};order[#order+1]=k end;g[k][#g[k]+1]=c end;table.sort(order,function(a,b)local pa=g[a][1]and tonumber(g[a][1].priority)or 5;local pb=g[b][1]and tonumber(g[b][1].priority)or 5;if pa~=pb then return pa<pb end;return a<b end);return order,g end
local function renderSetup(e,env,meta)
 local list=candidateList(meta);center(e,6,"SET UP DOOR",C.text,nil,2,e.w-1)
 if #list==0 then center(e,9,"NO REDSTONE ACTUATOR",C.warn,nil,2,e.w-1);center(e,11,"CONNECT INTEGRATOR / REDSTONE",C.dim,nil,2,e.w-1);sensorStrip(e,meta,env);return end
 local order,g=groups(list);local chosen=g[order[1]]or{};local first=chosen[1];center(e,8,nice(first and(first.type or first.controller)or"CONTROLLER"),C.dim,nil,2,e.w-1)
 if first and #chosen==1 and not first.side then button(e,"door_register",3,11,e.w-2,14,"USE THIS ACTUATOR",{target=first.target,side=nil,name=computerName()})else center(e,10,"TAP OUTPUT TO DOOR",C.dim,nil,2,e.w-1);local left,right,gap=3,e.w-2,1;local cell=math.floor((right-left+1-gap*2)/3);for i,c in ipairs(chosen)do if i>6 then break end;local col,row=(i-1)%3,math.floor((i-1)/3);local x1=left+col*(cell+gap);local x2=col==2 and right or x1+cell-1;local y=12+row*3;button(e,"door_register",x1,y,x2,y+1,nice(c.side or c.label or"OUT"),{target=c.target,side=c.side,name=computerName()},C.action)end end;sensorStrip(e,meta,env)
end
local function renderRoom(e,env,meta)prep(e);header(e,meta,env);if not renderDoor(e,env,meta)then renderSetup(e,env,meta)end end
local function renderSensor(e,env,meta)prep(e);header(e,meta,env);local s,n,scope=sensorInfo(meta,env);center(e,7,scope.." SENSORS",C.dim,nil,2,e.w-1);if s then center(e,10,sensorTitle(s),C.text,nil,2,e.w-1);local k,v=sensorMetric(s);center(e,13,k.."  "..v,C.good,nil,2,e.w-1);center(e,16,tostring(n).." AVAILABLE",C.dim,nil,2,e.w-1)else center(e,11,"NO SENSOR DATA",C.warn,nil,2,e.w-1)end end
local function renderStatus(e,env,meta)prep(e);header(e,meta,env);center(e,math.max(7,math.floor(e.h/2)),gameTime(),C.text,nil,2,e.w-1);local s=sensorInfo(meta,env);if s then local k,v=sensorMetric(s);center(e,math.max(9,math.floor(e.h/2)+3),k.."  "..v,C.good,nil,2,e.w-1)end end
local function drawErrorOn(e,err)
 pcall(e.mon.setTextScale,1);pcall(e.mon.setBackgroundColor,C.bg);pcall(e.mon.setTextColor,C.bad);pcall(e.mon.clear);pcall(e.mon.setCursorPos,2,2);pcall(e.mon.write,"KIMI UI ERROR");pcall(e.mon.setTextColor,C.text);local msg=tostring(err or"unknown error");for i=1,math.min(4,math.ceil(#msg/math.max(1,e.w-2)))do local part=msg:sub((i-1)*(e.w-2)+1,i*(e.w-2));pcall(e.mon.setCursorPos,2,3+i);pcall(e.mon.write,part)end
end
local function renderAll(env,meta)
 local mons=detectMonitors();for i,e in ipairs(mons)do if i==1 then renderRoom(e,env,meta)elseif i==2 then renderSensor(e,env,meta)else renderStatus(e,env,meta)end end
end
local function safeRender(env,meta)
 local ok,err=pcall(renderAll,env,meta);if ok then return true end;local mons=detectMonitors();for _,e in ipairs(mons)do drawErrorOn(e,err)end;return false,err
end

function M.init(c)cfg=c or{};targets={}end
function M.render(env,meta)lastEnv,lastMeta=env,meta;return safeRender(env,meta)end
function M.onPeripheralChange()if lastEnv then safeRender(lastEnv,lastMeta)end end
function M.handleEvent(ev,env,action)
 if ev[1]~="monitor_touch"then return false end;local name,x,y=ev[2],tonumber(ev[3]),tonumber(ev[4]);if not name or not x or not y then return false end
 for _,t in ipairs(targets[name]or{})do if x>=t.x1 and x<=t.x2 and y>=t.y1 and y<=t.y2 then local ok,res
  if t.name=="door_toggle"then local d=localDoors(lastMeta)[1];local mode=d and tostring(d.mode or"hold")or"hold";ok,res=action("__local_doors",mode=="pulse"and"pulse"or"toggle",t.data)
  elseif t.name=="door_register"then ok,res=action("__local_doors","register_local",t.data)
  elseif t.name=="door_mode"then local d=t.data or{};local nextMode=d.mode=="hold"and"invert"or(d.mode=="invert"and"pulse"or"hold");ok,res=action("__local_doors","configure_local",{_source=tostring(os.getComputerID()),target=d.target,side=d.side,mode=nextMode})end
  if lastEnv then safeRender(lastEnv,lastMeta)end;return ok,res
 end end;return false
end
return M
