local base=require("clients.admin_v15")
local M={}
local cfg={}
local lastEnv,lastMeta=nil,nil
local currentView="home"
local targets={}
local pending={}
local status=""
local C={bg=colors.black,text=colors.white,dim=colors.lightGray,good=colors.lime,warn=colors.orange,bad=colors.red,panel=colors.gray,action=colors.blue}

local function upper(v)return tostring(v or""):upper()end
local function state(env)return env and env.state or{}end
local function doors(env)return state(env).doors and state(env).doors.doors or{}end
local function now()local ok,v=pcall(os.epoch,"utc");return ok and tonumber(v)or 0 end
local function doorKey(d)return tostring(d and(d.key or d.id)or"").."|"..tostring(d and(d._source or d.source)or"").."|"..tostring(d and d.target or"").."|"..tostring(d and d.side or"")end

local function isMonitor(n)local ok,t=pcall(peripheral.getType,n);if ok and t=="monitor"then return true end;if type(peripheral.hasType)=="function"then local ok2,v=pcall(peripheral.hasType,n,"monitor");if ok2 and v then return true end end;return false end
local function detectMonitors()local out={};local ok,names=pcall(peripheral.getNames);if not ok or type(names)~="table"then return out end;for _,n in ipairs(names)do if isMonitor(n)then local okW,m=pcall(peripheral.wrap,n);if okW and m then local scale=1;pcall(m.setTextScale,scale);local okS,w,h=pcall(m.getSize);if okS then w,h=tonumber(w),tonumber(h);if w<22 or h<12 then scale=.5;pcall(m.setTextScale,scale);local ok2,w2,h2=pcall(m.getSize);if ok2 then w,h=tonumber(w2)or w,tonumber(h2)or h end end;out[#out+1]={name=n,mon=m,w=w,h=h,scale=scale,area=w*h}end end end end;table.sort(out,function(a,b)if a.area~=b.area then return a.area>b.area end;if a.w~=b.w then return a.w>b.w end;return a.name<b.name end);return out end
local function put(e,x,y,text,fg,bg)if y<1 or y>e.h or x>e.w then return end;x=math.max(1,x);text=tostring(text or"");e.mon.setCursorPos(x,y);e.mon.setTextColor(fg or C.text);e.mon.setBackgroundColor(bg or C.bg);e.mon.write(text:sub(1,math.max(0,e.w-x+1)));e.mon.setBackgroundColor(C.bg)end
local function fill(e,x1,y1,x2,y2,bg)x1,x2=math.max(1,x1),math.min(e.w,x2);y1,y2=math.max(1,y1),math.min(e.h,y2);if x2<x1 or y2<y1 then return end;for y=y1,y2 do put(e,x1,y,string.rep(" ",x2-x1+1),C.text,bg)end end
local function center(e,y,text,fg,bg,x1,x2)x1,x2=x1 or 1,x2 or e.w;local w=x2-x1+1;text=tostring(text or"");if #text>w then text=text:sub(1,w)end;put(e,x1+math.max(0,math.floor((w-#text)/2)),y,text,fg,bg)end
local function reg(e,x1,y1,x2,y2,d)targets[e.name]=targets[e.name]or{};targets[e.name][#targets[e.name]+1]={x1=x1,y1=y1,x2=x2,y2=y2,door=d,key=doorKey(d)}end

local function visibleOpen(d)
 local k=doorKey(d);local p=pending[k]
 if p then
  if d and d.open==p.desired then pending[k]=nil;return d.open==true,false end
  if now()-p.at<=8000 then return p.desired,true end
  pending[k]=nil
 end
 return d and d.open==true,false
end

local function findDoor(env,k)for _,d in ipairs(doors(env))do if doorKey(d)==k then return d end end end
local function drawAction(e,x1,y1,x2,y2,d)
 local opened,shadow=visibleOpen(d)
 local st=d.online==false and"OFFLINE"or(opened and"OPEN"or"CLOSED")
 put(e,x1,y1,upper(d.name or"DOOR"),C.text)
 put(e,math.max(x1,x2-#st+1),y1,st,d.online==false and C.bad or(opened and C.good or C.dim))
 if d.online==false then
  fill(e,x1,y1+1,x2,y2,C.panel);center(e,math.floor((y1+1+y2)/2),"OFFLINE",C.dim,C.panel,x1+1,x2-1);return
 end
 local label=opened and"CLOSE DOOR"or"OPEN DOOR"
 local bg=opened and C.warn or C.good
 fill(e,x1,y1+1,x2,y2,bg);center(e,math.floor((y1+1+y2)/2),label,C.bg,bg,x1+1,x2-1)
 reg(e,x1,y1+1,x2,y2,d)
 if shadow then put(e,x1,y1,upper(d.name or"DOOR").." *",C.text)end
end

local function drawHome(e,env)
 local x1=math.floor(e.w*.52)+2;local x2=e.w-2;local y1=5;local y2=e.h-8
 if x2-x1<12 or y2-y1<4 then return end
 fill(e,x1,y1,x2,y2,C.bg);put(e,x1,y1,"DOOR CONTROL",C.dim);put(e,x2-2,y1,tostring(#doors(env)),#doors(env)>0 and C.good or C.dim)
 local y=y1+2
 for _,d in ipairs(doors(env))do if y+2>y2 then break end;drawAction(e,x1,y,x2,y+2,d);y=y+4 end
 if #doors(env)==0 then center(e,y1+3,"NO DOORS",C.dim,nil,x1,x2)end
end

local function drawDoorsPage(e,env)
 local x1=2;local x2=e.w-2;local y1=5;local y2=e.h-5
 fill(e,x1,y1,x2,y2,C.bg);put(e,x1,y1,"BIG SCREEN DOOR CONTROL",C.dim)
 local y=y1+2
 for _,d in ipairs(doors(env))do if y+2>y2 then break end;drawAction(e,x1,y,x2,y+2,d);y=y+4 end
 if #doors(env)==0 then center(e,y1+4,"NO DOORS CONFIGURED",C.dim,nil,x1,x2)end
 if status~=""and y2>=y1+2 then put(e,x1,y2,status,C.dim)end
end

local function navAt(e,x,y,compact)
 if e.w<38 or e.h<16 or y<e.h-2 then return nil end
 local items=compact and{"home","doors","sensors"}or{"home","doors","power","sensors","fleet"}
 local left,right,gap=2,e.w-1,1;local cell=math.floor((right-left+1-gap*(#items-1))/#items)
 for i,v in ipairs(items)do local a=left+(i-1)*(cell+gap);local b=i==#items and right or a+cell-1;if x>=a and x<=b then return v end end
end

function M.init(c)cfg=c or{};currentView="home";targets={};pending={};status="";return base.init(c)end
function M.render(env,meta)
 lastEnv,lastMeta=env,meta;targets={}
 local ok=base.render(env,meta)
 local mons=detectMonitors();local main=mons[1]
 if main then
  pcall(main.mon.setTextScale,main.scale)
  if currentView=="home"then drawHome(main,env)elseif currentView=="doors"then drawDoorsPage(main,env)end
 end
 return ok
end
function M.onPeripheralChange(...)targets={};if base.onPeripheralChange then return base.onPeripheralChange(...)end end
function M.handleEvent(ev,env,action)
 if ev[1]~="monitor_touch"then return base.handleEvent and base.handleEvent(ev,env,action)or false end
 local name,x,y=ev[2],tonumber(ev[3]),tonumber(ev[4])
 for _,t in ipairs(targets[name]or{})do
  if x and y and x>=t.x1 and x<=t.x2 and y>=t.y1 and y<=t.y2 then
   local d=findDoor(env,t.key)or t.door
   if not d or d.online==false then status="DOOR OFFLINE";M.render(env,lastMeta);return true end
   local opened=select(1,visibleOpen(d));local desired=not opened;local cmd=desired and"open"or"close"
   local args={source=d._source or d.source or"server",target=d.target,side=d.side,id=d.id,key=d.key}
   local callOk,result=pcall(action,"remote_doors_async",cmd,args)
   if not callOk or(type(result)=="table"and result.ok==false)then
    status="DOOR COMMAND FAILED";pending[t.key]=nil
   else
    pending[t.key]={desired=desired,at=now()};status=desired and"OPEN REQUESTED"or"CLOSE REQUESTED"
   end
   M.render(env,lastMeta);return true
  end
 end
 local mons=detectMonitors();local main=mons[1];local nav=nil
 if main and name==main.name and x and y then nav=navAt(main,x,y,#mons>=3)end
 local handled=base.handleEvent and base.handleEvent(ev,env,action)or false
 if nav then currentView=nav;M.render(env,lastMeta);return true end
 return handled
end
return M
