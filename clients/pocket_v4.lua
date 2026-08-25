local M={}
local cfg={}
local page=1
local lastEnv,lastMeta
local lastStatus="READY"
local doorCards={}
local shadow={}
local pages={"HOME","DOORS","JUICE","SENS","FLEET"}
local C={bg=colors.black,text=colors.white,dim=colors.lightGray,good=colors.lime,warn=colors.orange,bad=colors.red,accent=colors.cyan or colors.lightBlue,button=colors.gray,active=colors.blue}

local function upper(v)return tostring(v or""):upper()end
local function clip(v,w)v=tostring(v or"");if #v<=w then return v end;if w<=3 then return v:sub(1,w)end;return v:sub(1,w-3).."..."end
local function size()local w,h=term.getSize();return tonumber(w)or 26,tonumber(h)or 20 end
local function put(x,y,text,fg,bg)local w,h=size();if y<1 or y>h or x>w then return end;x=math.max(1,x);term.setCursorPos(x,y);term.setTextColor(fg or C.text);term.setBackgroundColor(bg or C.bg);term.write(clip(text,w-x+1));term.setBackgroundColor(C.bg)end
local function fill(x1,y1,x2,y2,bg)local w,h=size();x1,x2=math.max(1,x1),math.min(w,x2);y1,y2=math.max(1,y1),math.min(h,y2);if x2<x1 or y2<y1 then return end;for y=y1,y2 do put(x1,y,string.rep(" ",x2-x1+1),C.text,bg)end end
local function center(y,text,fg,bg,x1,x2)local w=size();x1,x2=x1 or 1,x2 or w;local width=x2-x1+1;text=clip(text,width);put(x1+math.max(0,math.floor((width-#text)/2)),y,text,fg,bg)end
local function clear()term.setBackgroundColor(C.bg);term.setTextColor(C.text);term.clear();term.setCursorPos(1,1)end
local function rule(y)local w=size();put(1,y,string.rep("-",w),C.dim)end
local function now()local ok,v=pcall(os.epoch,"utc");return ok and tonumber(v)or 0 end
local function gameTime()local ok,t=pcall(os.time,"ingame");t=ok and tonumber(t)or 0;local h=math.floor(t%24);local m=math.floor((((t%24)-h)*60)+.5)%60;return string.format("%02d:%02d",h,m)end
local function state(env)return env and env.state or{}end
local function doors(env)local d=state(env).doors;return d and d.doors or{}end
local function sensors(env)local a=state(env).attachments;return a and a.sensors or{}end
local function fleet(env)local f=state(env).fleet or{};local total,online,current=0,0,0;local target=tostring(env and env.version or"");for _,m in pairs(f)do total=total+1;if m.online~=false then online=online+1;if tostring(m.version or"")==target then current=current+1 end end end;return total,online,current end
local function power(env)local p=state(env).power or{};local best,score=p,-1;local function use(x)if type(x)~="table"then return end;local cap=tonumber(x.capacity)or 0;local stored=tonumber(x.stored)or 0;local s=(cap>0 and 1e9 or 0)+(stored>0 and 1e6 or 0)+math.abs(tonumber(x.input)or 0)+math.abs(tonumber(x.output)or 0);if s>score then best,score=x,s end end;use(p);for _,x in ipairs(p.matrices or{})do use(x)end;for _,x in ipairs(p.fluxNetworks or{})do use(x)end;return best or p end
local function pct(p)local n=tonumber(p and p.filledPercentage);if n then if n<=1 then n=n*100 end;return math.max(0,math.min(100,n))end;local s,c=tonumber(p and p.stored),tonumber(p and p.capacity);if s and c and c>0 then return math.max(0,math.min(100,s/c*100))end end
local function fmt(n)n=tonumber(n);if not n then return"?"end;local a=math.abs(n);if a>=1e12 then return string.format("%.1fT",n/1e12)elseif a>=1e9 then return string.format("%.1fG",n/1e9)elseif a>=1e6 then return string.format("%.1fM",n/1e6)elseif a>=1e3 then return string.format("%.1fK",n/1e3)end;return tostring(math.floor(n+0.5))end
local function title()local l=type(os.getComputerLabel)=="function"and os.getComputerLabel()or nil;return l and tostring(l):match("%S")and upper(l)or"KIMI POCKET"end
local function header()local w=size();put(1,1,clip(title(),math.max(1,w-6)),C.text);put(math.max(1,w-4),1,gameTime(),C.dim);rule(2)end
local function footer()local w,h=size();rule(h-2);local label="< "..pages[page].." >";put(math.max(1,math.floor((w-#label)/2)+1),h-1,label,C.accent);put(1,h,clip(lastStatus,w),lastStatus:find("ERR",1,true)and C.bad or C.dim)end
local function doorKey(d)return tostring(d and(d.id or d.key or((d._source or d.source or"?").."|"..tostring(d.target or"?").."|"..tostring(d.side or"?")))or"?")end
local function visibleState(d)
 local key=doorKey(d);local s=shadow[key]
 if s then
  if d and d.open==s.desired then shadow[key]=nil;return d.open==true,nil end
  if now()-s.at<=3000 then return s.desired,s end
  shadow[key]=nil
 end
 return d and d.open==true,nil
end
local function sendDoor(d,desired,action)
 if not d then lastStatus="ERR NO DOOR";return false end
 local args={_source=d._source or d.source,target=d.target,side=d.side,id=d.id,key=d.key}
 local cmd=desired and"open"or"close"
 local ok,res=action("remote_doors",cmd,args)
 if ok==false then lastStatus="ERR "..clip(tostring(res or"COMMAND FAILED"),20);return false end
 shadow[doorKey(d)]={desired=desired,at=now()}
 lastStatus=(desired and"OPEN SENT  "or"CLOSE SENT ")..clip(upper(d.name or"DOOR"),12)
 return true
end
local function commandDoor(d,action)local opened=select(1,visibleState(d));return sendDoor(d,not opened,action)end
local function drawDoorControl(d,y,w,compact)
 local opened,s=visibleState(d);local name=upper(d.name or"DOOR")
 put(1,y,clip(name,w),C.text)
 local stateText=s and(s.desired and"OPENING"or"CLOSING")or(opened and"OPEN"or"CLOSED")
 center(y+1,stateText,s and C.warn or(opened and C.good or C.dim))
 local by1=y+3;local by2=compact and by1 or by1+1;local bg=opened and C.active or C.button
 fill(1,by1,w,by2,bg);center(math.floor((by1+by2)/2),opened and"CLOSE DOOR"or"OPEN DOOR",C.text,bg)
 doorCards[#doorCards+1]={y1=y,y2=by2,door=d}
 return by2
end
local function drawHome(env,meta)
 doorCards={};local ds=doors(env);local p=power(env);local pp=pct(p);local total,online,current=fleet(env);local w=size()
 put(1,4,meta and meta.connected and"BASE ONLINE"or"BASE OFFLINE",meta and meta.connected and C.good or C.warn)
 put(1,5,"JUICE "..(pp and string.format("%.1f%%",pp)or"NO DATA"),pp and C.good or C.warn)
 put(1,6,"FLEET "..online.."/"..total.."  CUR "..current,C.dim)
 rule(8);put(1,9,"QUICK DOOR",C.dim)
 if ds[1]then local bottom=drawDoorControl(ds[1],10,w,false);if #ds>1 and bottom+1<size()then put(1,bottom+1,"+"..tostring(#ds-1).." MORE > DOORS",C.accent)end else center(12,"NO CONFIGURED DOORS",C.warn)end
end
local function drawDoors(env)
 doorCards={};local ds=doors(env);local w,h=size();put(1,4,"DOORS  "..#ds,C.text);if #ds==0 then center(8,"NO CONFIGURED DOORS",C.warn);return end
 local y=6;for i,d in ipairs(ds)do if y+4>h-3 then break end;put(1,y,tostring(i)..".",C.dim);local bottom=drawDoorControl(d,y,w,true);y=bottom+2 end
end
local function drawJuice(env)local p=power(env);local pp=pct(p);put(1,4,"JUICE / POWER",C.text);center(6,pp and string.format("%.1f%%",pp)or"NO DATA",pp and C.good or C.warn);put(1,9,"STORED   "..fmt(p.stored).." FE",C.text);put(1,10,"CAPACITY "..fmt(p.capacity).." FE",C.dim);put(1,12,"IN   +"..fmt(p.input).." FE/t",C.good);put(1,13,"OUT  -"..fmt(p.output).." FE/t",C.warn)end
local function sensorSummary(s)local m=s and s.metrics or{};if m.temperature~=nil then return"TEMP "..tostring(m.temperature)end;if m.onlinePlayers~=nil then return"PLAYERS "..tostring(m.onlinePlayers)end;if m.weather~=nil then return upper(m.weather)end;if m.radiationRaw~=nil then return"RAD "..tostring(m.radiationRaw)end;return upper(s and s.summary or"ONLINE")end
local function drawSensors(env)local ss=sensors(env);put(1,4,"SENSORS  "..#ss,#ss>0 and C.good or C.warn);if #ss==0 then put(1,6,"NO TELEMETRY",C.warn);return end;local _,h=size();local y=6;for i,s in ipairs(ss)do if y>=h-3 then break end;put(1,y,clip(upper(s.type or("SENSOR "..i)),24),C.text);put(1,y+1,clip(sensorSummary(s),24),C.good);y=y+3 end end
local function drawFleet(env)local f=state(env).fleet or{};local total,online,current=fleet(env);put(1,4,"FLEET "..online.."/"..total,C.text);put(1,5,"CURRENT "..current.."/"..total,current==total and total>0 and C.good or C.warn);local ids={};for id in pairs(f)do ids[#ids+1]=id end;table.sort(ids,function(a,b)return tostring(a)<tostring(b)end);local _,h=size();local y=7;for _,id in ipairs(ids)do if y>=h-3 then break end;local m=f[id];put(1,y,clip(upper(m.name or m.role or("PC "..id)),16),m.online==false and C.bad or C.good);put(17,y,clip(m.version or"?",10),C.dim);y=y+1 end end
local draws={drawHome,drawDoors,drawJuice,drawSensors,drawFleet}
local function render(env,meta)clear();header();if not meta or not meta.connected or not env then put(1,5,"SEARCHING MAIN BASE...",C.warn);footer();return end;draws[page](env,meta);footer()end
function M.init(c)cfg=c or{};page=1;shadow={};clear()end
function M.render(env,meta)lastEnv,lastMeta=env,meta;render(env,meta);return true end
function M.onState(env)lastEnv=env;for _,d in ipairs(doors(env))do visibleState(d)end end
function M.handleEvent(ev,env,action)
 if ev[1]=="key" and type(keys)=="table" then
  local k=ev[2]
  if k==keys.left then page=page==1 and#pages or page-1
  elseif k==keys.right then page=page==#pages and 1 or page+1
  elseif page==1 or page==2 then
   local nums={keys.one,keys.two,keys.three,keys.four,keys.five,keys.six,keys.seven,keys.eight,keys.nine};local idx
   for i,v in ipairs(nums)do if v~=nil and k==v then idx=i break end end
   if idx then commandDoor(doors(lastEnv)[idx],action)else return false end
  else return false end
  render(lastEnv,lastMeta);return true
 elseif ev[1]=="mouse_scroll" then
  if(tonumber(ev[2])or 0)>0 then page=page==#pages and 1 or page+1 else page=page==1 and#pages or page-1 end;render(lastEnv,lastMeta);return true
 elseif ev[1]=="mouse_click" and(page==1 or page==2)then
  local y=tonumber(ev[4]);for _,c in ipairs(doorCards)do if y and y>=c.y1 and y<=c.y2 then commandDoor(c.door,action);render(lastEnv,lastMeta);return true end end
 end
 return false
end
return M
