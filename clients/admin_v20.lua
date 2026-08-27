local base=require("clients.admin_v19")
local M={}
for k,v in pairs(base)do M[k]=v end

local C={bg=colors.black,text=colors.white,dim=colors.lightGray,good=colors.lime,warn=colors.orange,bad=colors.red,panel=colors.gray}
local lastEnv,lastMeta
local fleetTargets={}
local fleetMessage=""
local function upper(v)return tostring(v or""):upper()end
local function now()local ok,v=pcall(os.epoch,"utc");return ok and tonumber(v)or 0 end
local function gameTime()local ok,t=pcall(os.time,"ingame");t=ok and tonumber(t)or 0;local h=math.floor(t%24);local m=math.floor(((t%24)-h)*60+.5)%60;return string.format("%02d:%02d",h,m)end
local function isMonitor(n)local ok,t=pcall(peripheral.getType,n);if ok and t=="monitor"then return true end;if type(peripheral.hasType)=="function"then local ok2,v=pcall(peripheral.hasType,n,"monitor");if ok2 and v then return true end end;return false end
local function detectMonitors()local out={};local ok,names=pcall(peripheral.getNames);if not ok or type(names)~="table"then return out end;for _,n in ipairs(names)do if isMonitor(n)then local okW,m=pcall(peripheral.wrap,n);if okW and m then local scale=1;pcall(m.setTextScale,scale);local okS,w,h=pcall(m.getSize);if okS then w,h=tonumber(w),tonumber(h);if w<22 or h<12 then scale=.5;pcall(m.setTextScale,scale);local ok2,w2,h2=pcall(m.getSize);if ok2 then w,h=tonumber(w2)or w,tonumber(h2)or h end end;out[#out+1]={name=n,mon=m,w=w,h=h,scale=scale,area=w*h}end end end end;table.sort(out,function(a,b)if a.area~=b.area then return a.area>b.area end;if a.w~=b.w then return a.w>b.w end;return a.name<b.name end);return out end
local function put(e,x,y,text,fg,bg)if y<1 or y>e.h or x>e.w then return end;text=tostring(text or"");e.mon.setCursorPos(math.max(1,x),y);e.mon.setTextColor(fg or C.text);e.mon.setBackgroundColor(bg or C.bg);e.mon.write(text:sub(1,math.max(0,e.w-x+1)));e.mon.setBackgroundColor(C.bg)end
local function rule(e,y)put(e,2,y,string.rep("-",math.max(0,e.w-2)),C.panel)end
local function statusFor(m,t)
 local seen=tonumber(m and m.lastSeen)or 0;local age=math.max(0,t-seen)
 if age<=10000 then return"ONLINE",C.good,age elseif age<=45000 then return"STALE",C.warn,age else return"OFFLINE",C.bad,age end
end
local function idLess(a,b)local na,nb=tonumber(a),tonumber(b);if na and nb then return na<nb end;if na then return true end;if nb then return false end;return tostring(a)<tostring(b)end
local function renderFleet(e,env)
 pcall(e.mon.setTextScale,e.scale);e.mon.setBackgroundColor(C.bg);e.mon.setTextColor(C.text);e.mon.clear();fleetTargets[e.name]={}
 put(e,2,1,"FLEET",C.text);put(e,math.max(2,e.w-6),1,gameTime(),C.dim);rule(e,3)
 local fleet=env and env.state and env.state.fleet or{};local ids={};for id in pairs(fleet or{})do ids[#ids+1]=id end;table.sort(ids,idLess)
 local t=now();local online,stale,offline=0,0,0;for _,id in ipairs(ids)do local st=statusFor(fleet[id],t);if st=="ONLINE"then online=online+1 elseif st=="STALE"then stale=stale+1 else offline=offline+1 end end
 put(e,2,5,"ON "..online,C.good);put(e,9,5,"STALE "..stale,stale>0 and C.warn or C.dim);put(e,18,5,"OFF "..offline,offline>0 and C.bad or C.dim);rule(e,7)
 local y=9;local targetVersion=tostring(env and env.version or"");local selfId=tostring(env and env.serverId or"")
 for _,id in ipairs(ids)do if y+1>e.h-3 then break end;local m=fleet[id]or{};local st,color=statusFor(m,t);local name=upper(m.name or m.role or("PC "..tostring(id)));put(e,2,y,name,C.text);put(e,math.max(2,e.w-#("#"..tostring(id))-1),y,"#"..tostring(id),C.dim);local ver=tostring(m.version or"");local vstat=(ver~=""and targetVersion~=""and ver~=targetVersion)and"UPDATE"or"CURRENT";if st~="ONLINE"then vstat=st end;put(e,2,y+1,st,color);put(e,math.max(2,e.w-#vstat-1),y+1,vstat,vstat=="CURRENT"and C.good or(vstat=="UPDATE"and C.warn or color));if tostring(id)~=selfId then fleetTargets[e.name][#fleetTargets[e.name]+1]={id=id,y1=y,y2=y+1,name=name}end;y=y+3 end
 if e.h>=3 then put(e,2,e.h-2,fleetMessage~=""and fleetMessage or"TOUCH MACHINE = IDENTIFY",fleetMessage~=""and C.warn or C.dim)end
end
function M.init(c)lastEnv,lastMeta=nil,nil;fleetTargets={};fleetMessage="";return base.init(c)end
function M.render(env,meta)
 lastEnv,lastMeta=env,meta;local ok=base.render(env,meta);local mons=detectMonitors();if mons[3]then renderFleet(mons[3],env)end;return ok
end
function M.handleEvent(ev,env,action)
 if ev[1]=="monitor_touch"then local name,x,y=ev[2],tonumber(ev[3]),tonumber(ev[4]);for _,t in ipairs(fleetTargets[name]or{})do if y and y>=t.y1 and y<=t.y2 then local ok,res=pcall(action,"system","identify",{_source=tostring(t.id),duration=10});if ok and not(type(res)=="table"and res.ok==false)then fleetMessage="IDENTIFY -> "..t.name else fleetMessage="IDENTIFY FAILED #"..tostring(t.id)end;M.render(env,lastMeta);return true end end end
 return base.handleEvent and base.handleEvent(ev,env,action)or false
end
function M.onPeripheralChange(...)fleetTargets={};if base.onPeripheralChange then return base.onPeripheralChange(...)end end
return M
