-- Alpha81 aspect-aware operational truth overlay.
-- Keep the proven v27/tall POWER layout, but overlay truthful fleet status on
-- every layout and the richer live-telemetry POWER dashboard on wide screens.
local base=require("clients.admin_v27")
local health=require("core.fleet_health")
local fleetDisplay=require("core.fleet_display")
local builderUI=require("clients.builder_dashboard")
local M={}
for k,v in pairs(base)do M[k]=v end

local C={bg=colors.black,text=colors.white,dim=colors.lightGray,good=colors.lime,warn=colors.orange,bad=colors.red,panel=colors.gray}
local lastEnv,lastMeta
local targets={}
local viewTargets={}
local lastRequest=nil
local forgetRequest=nil
local localMessage=""
local sharedView=nil
local builderPage=1

local function upper(v)return tostring(v or""):upper()end
local function nice(v)return upper(tostring(v or""):gsub("minecraft:",""):gsub("[_%-]"," "):gsub("(%l)(%u)","%1 %2"))end
local function state(env)return env and env.state or{}end
local function now()
 if type(os.epoch)=="function"then local ok,v=pcall(os.epoch,"utc");if ok and tonumber(v)then return tonumber(v)end end
 local ok,t=pcall(os.time,"ingame");return math.floor((ok and tonumber(t)or 0)*1000)
end
local function gameTime()local ok,t=pcall(os.time,"ingame");t=ok and tonumber(t)or 0;local h=math.floor(t%24);local m=math.floor(((t%24)-h)*60+.5)%60;return string.format("%02d:%02d",h,m)end
local function sameId(a,b)return a~=nil and b~=nil and tostring(a)==tostring(b)end
local function fmt(n)local v=tonumber(n);if not v then return"?"end;local a=math.abs(v);if a>=1e15 then return string.format("%.1fP",v/1e15)elseif a>=1e12 then return string.format("%.1fT",v/1e12)elseif a>=1e9 then return string.format("%.1fG",v/1e9)elseif a>=1e6 then return string.format("%.1fM",v/1e6)elseif a>=1e3 then return string.format("%.1fK",v/1e3)end;return tostring(math.floor(v+.5))end
local function pct(p)local n=tonumber(p and p.filledPercentage);if n then if n<=1 then n=n*100 end;return math.max(0,math.min(100,n))end;local s,c=tonumber(p and p.stored),tonumber(p and p.capacity);if s and c and c>0 then return math.max(0,math.min(100,s/c*100))end end

local function isMonitor(n)local ok,t=pcall(peripheral.getType,n);if ok and t=="monitor"then return true end;if type(peripheral.hasType)=="function"then local ok2,v=pcall(peripheral.hasType,n,"monitor");if ok2 and v then return true end end;return false end
local function monitors()
 local out={};local ok,names=pcall(peripheral.getNames);if not ok or type(names)~="table"then return out end
 for _,n in ipairs(names)do if isMonitor(n)then local okw,m=pcall(peripheral.wrap,n);if okw and m then local scale=1;pcall(m.setTextScale,scale);local oks,w,h=pcall(m.getSize);if oks then w,h=tonumber(w),tonumber(h);if w<22 or h<12 then scale=.5;pcall(m.setTextScale,scale);local ok2,w2,h2=pcall(m.getSize);if ok2 then w,h=tonumber(w2)or w,tonumber(h2)or h end end;out[#out+1]={name=n,mon=m,w=w,h=h,area=w*h,scale=scale}end end end end
 table.sort(out,function(a,b)if a.area~=b.area then return a.area>b.area end;if a.w~=b.w then return a.w>b.w end;return a.name<b.name end);return out
end
local function prep(e)pcall(e.mon.setTextScale,e.scale);e.mon.setBackgroundColor(C.bg);e.mon.setTextColor(C.text);e.mon.clear()end
local function put(e,x,y,text,fg,bg)if not e or y<1 or y>e.h or x>e.w then return end;x=math.max(1,x);text=tostring(text or"");e.mon.setCursorPos(x,y);e.mon.setBackgroundColor(bg or C.bg);e.mon.setTextColor(fg or C.text);e.mon.write(text:sub(1,math.max(0,e.w-x+1)));e.mon.setBackgroundColor(C.bg)end
local function fill(e,x1,y1,x2,y2,bg)x1,x2=math.max(1,x1),math.min(e.w,x2);y1,y2=math.max(1,y1),math.min(e.h,y2);if x2<x1 or y2<y1 then return end;for y=y1,y2 do put(e,x1,y,string.rep(" ",x2-x1+1),C.text,bg)end end
local function rule(e,y)put(e,2,y,string.rep("-",math.max(0,e.w-2)),C.panel)end
local function header(e,title)put(e,2,1,title,C.text);put(e,math.max(2,e.w-6),1,gameTime(),C.dim);local label=(type(os.getComputerLabel)=="function"and os.getComputerLabel())or"MAIN BASE";put(e,2,2,upper(label),C.dim);rule(e,3)end

local function fleetEntries(env)
 local fleet=state(env).fleet or{};local serverId=env and env.serverId;local t=now();local out={};local counts={ONLINE=0,LATE=0,OFFLINE=0}
 for _,displayRow in ipairs(fleetDisplay.rows(fleet,serverId))do
  local id,m=displayRow.transportId,displayRow.m or{};local status,age=health.reachability(id,m,serverId,t);local main=displayRow.main
  if main then status="MAIN";counts.ONLINE=counts.ONLINE+1 else counts[status]=(counts[status]or 0)+1 end
  out[#out+1]={id=id,displayId=displayRow.displayId,m=m,status=status,age=age,main=main}
 end
 table.sort(out,function(a,b)local rank={MAIN=0,ONLINE=1,LATE=2,OFFLINE=3};local ra,rb=rank[a.status]or 9,rank[b.status]or 9;if ra~=rb then return ra<rb end;return (a.displayId or 999)<(b.displayId or 999)end)
 return out,counts,t
end
local function feedback(t)
 if localMessage~=""then return localMessage,C.warn end
 if not lastRequest then return"ONLINE: IDENTIFY   OFFLINE: TAP TWICE TO FORGET",C.dim end
 local acks=rawget(_G,"kimiIdentifyAck")or{};local ack=acks[tostring(lastRequest.id)]
 local shown=lastRequest.displayId or lastRequest.id
 if type(ack)=="table"and tonumber(ack.at)and tonumber(ack.at)>=lastRequest.at then return"CONFIRMED ID "..tostring(shown).." FLASHING",C.good end
 if t-lastRequest.at<3000 then return"WAITING FOR ID "..tostring(shown).." ACK...",C.warn end
 return"ID "..tostring(shown).." NOT REACHABLE",C.bad
end
local function renderFleet(e,env)
 prep(e);targets[e.name]={};header(e,"FLEET / IDENTIFY");local rows,c,t=fleetEntries(env)
 put(e,2,4,"VERSION "..tostring(env and env.version or"?"),C.dim);put(e,2,5,"ONLINE "..c.ONLINE.."  LATE "..c.LATE.."  OFFLINE "..c.OFFLINE,(c.LATE+c.OFFLINE)>0 and C.warn or C.good)
 local msg,fg=feedback(t);put(e,2,6,msg,fg);rule(e,7);if e.w>=42 then put(e,2,8,"KIMI ID 1 = MAIN   CC TRANSPORT IDS ARE HIDDEN",C.dim)end
 local y=e.w>=42 and 10 or 9;local shown=0
 for _,row in ipairs(rows)do if y+1>e.h then break end;local id,m,status=row.id,row.m,row.status;local displayId=row.displayId or id;local name=upper(m.name or m.role or("KIMI-"..tostring(displayId)));local sf=status=="OFFLINE"and C.bad or(status=="LATE"and C.warn or C.good);put(e,2,y,"ID "..tostring(displayId).." "..name,C.text);put(e,math.max(2,e.w-#status-1),y,status,sf);put(e,2,y+1,upper(m.role or"?").."  "..tostring(m.version or"?"),C.dim);local seen=row.main and"LOCAL"or("SEEN "..health.ageText(row.age));put(e,math.max(2,e.w-#seen-1),y+1,seen,status=="OFFLINE"and C.bad or C.dim);targets[e.name][#targets[e.name]+1]={y1=y,y2=y+1,id=tonumber(id)or id,displayId=displayId,name=name,main=row.main,status=status,age=row.age};y=y+3;shown=shown+1 end
 if #rows>shown and e.h>=2 then put(e,2,e.h,"+"..tostring(#rows-shown).." MORE REMEMBERED",C.dim)end
end

local function dataRank(v)local s=upper(v and v._telemetryStatus or"LIVE");if s=="LIVE"then return 2 elseif s=="CACHED"then return 1 end;return 0 end
local function biggestMatrix(list)local best,rank,cap=nil,-1,-1;for _,m in ipairs(list or{})do local r=dataRank(m);local c=tonumber(m.capacity)or 0;if r>rank or(r==rank and c>cap)then best,rank,cap=m,r,c end end;return best end
local function sourcePowerInfo(env)
 local st=state(env);local t=now();local serverId=env and env.serverId;local out={}
 for id,s in pairs(st.sources or{})do local p=s.state and s.state.power;local matrices=type(p)=="table"and p.matrices or nil;local flux=type(p)=="table"and p.fluxNetworks or nil;if (type(matrices)=="table"and #matrices>0)or(type(flux)=="table"and #flux>0)then local seen=s.lastHeartbeat or s.lastSeen;local status,age=health.reachability(id,{lastSeen=seen},serverId,t);out[#out+1]={id=id,name=s.name or("KIMI-"..tostring(id)),status=status,age=age,matrices=matrices or{},flux=flux or{}}end end
 return out
end
local function offlineMatrixHint(env)local best=nil;for _,s in ipairs(sourcePowerInfo(env))do if #s.matrices>0 and s.status~="ONLINE"then if not best or s.age<best.age then best=s end end end;return best end
local function renderPowerWide(e,env)
 prep(e);header(e,"POWER / TELEMETRY");local st=state(env);local p=st.power or{};local matrices=p.matrices or{};local fx=p.fluxNetworks or{};local rs=st.power_reserve or{};local main=biggestMatrix(matrices);local mp=pct(main);local mainData=upper(main and(main._telemetryStatus or"LIVE")or"MISSING");local mainColor=mainData=="LIVE"and C.good or C.warn
 local col=math.max(12,math.floor((e.w-6)/3));local a1=2;local a2=math.min(e.w-2,a1+col-1);local b1=a2+2;local b2=math.min(e.w-2,b1+col-1);local c1=b2+2
 put(e,a1,5,"MAIN MATRIX",C.dim)
 if main then put(e,a1,6,(mp and string.format("%.1f%%",mp)or"DATA").."  "..mainData,mainColor);fill(e,a1,7,a2,7,C.panel);if mp then local n=math.floor((a2-a1+1)*mp/100+.5);if n>0 then fill(e,a1,7,a1+n-1,7,mainColor)end end;put(e,a1,9,"STORED "..fmt(main.stored).." FE",C.text);put(e,a1,10,"CAP "..fmt(main.capacity).." FE",C.dim);if e.h>=12 then put(e,a1,11,"IN  +"..fmt(main.input).."/t",mainColor);put(e,a1,12,"OUT -"..fmt(main.output).."/t",C.dim)end
 else put(e,a1,6,"NO LIVE MATRIX TELEMETRY",C.bad);local hint=offlineMatrixHint(env);if hint then put(e,a1,8,upper(hint.name),C.warn);put(e,a1,9,"LAST SEEN "..health.ageText(hint.age),C.dim)else put(e,a1,8,"CHECK MATRIX NODE",C.warn)end end
 put(e,b1,5,"RESERVE",C.dim);if not main or mainData~="LIVE"then put(e,b1,6,"WAITING FOR LIVE MAIN",C.warn);if main then put(e,b1,8,"CACHED DATA IS DISPLAY ONLY",C.dim)end else local status=upper(rs.status or(rs.configured and"ARMED"or"NOT CONFIGURED"));if status=="NO MAIN MATRIX"then status="WAITING FOR TELEMETRY"end;put(e,b1,6,status,rs.feeding and C.warn or(rs.configured and C.good or C.dim));if rs.reservePercent~=nil then put(e,b1,8,string.format("%.1f%%",tonumber(rs.reservePercent)or 0),C.good)elseif #matrices<2 then put(e,b1,8,"NO LIVE BACKUP MATRIX",C.dim)end;put(e,b1,10,"FEED <= "..tostring(math.floor(tonumber(rs.lowPercent) or 20)).."%",C.dim);if e.h>=11 then put(e,b1,11,"STOP >= "..tostring(math.floor(tonumber(rs.highPercent) or 80)).."%",C.dim)end end
 local liveFlux=0;for _,n in ipairs(fx)do if upper(n._telemetryStatus or"LIVE")=="LIVE"then liveFlux=liveFlux+1 end end
 put(e,c1,5,"FLUX NETWORKS",C.dim);put(e,c1,6,tostring(#fx).." FOUND / "..liveFlux.." LIVE",#fx>0 and(liveFlux>0 and C.good or C.warn)or C.bad);if #fx==0 then put(e,c1,8,"NO LIVE FLUX TELEMETRY",C.warn)else local y=8;for i,n in ipairs(fx)do if y>e.h then break end;local ds=upper(n._telemetryStatus or"LIVE");put(e,c1,y,nice(n.networkName or n.name or n.peripheral or("NETWORK "..i)),C.text);if y+1<=e.h then put(e,c1,y+1,fmt(n.stored).." FE  "..ds,ds=="LIVE"and C.good or C.warn)end;y=y+2 end end
end

local function builders(env)local b=state(env).builder or{};return b.builders or{}end
local function plannedBuilderMonitor(ms,env)
 local extras={};for i=4,#ms do extras[#extras+1]=ms[i]end;if#extras==0 then return nil end
 local envIndex,envScore=1,-1;for i,e in ipairs(extras)do local score=(e.w/math.max(1,e.h))*1000+e.area;if score>envScore then envIndex,envScore=i,score end end;table.remove(extras,envIndex)
 local ae=state(env).ae2 or{};if#extras>0 and(ae.bridge or ae.online==true or ae.connected==true)then table.remove(extras,1)end
 return extras[1]
end
local function paintViewButton(e,label)
 local x1=math.max(2,e.w-#label-3);fill(e,x1,2,e.w-1,2,colors.blue);put(e,x1+1,2,label,C.text,colors.blue);viewTargets[e.name]={x1=x1,x2=e.w-1,y=2,action=label}
end
local function renderBuilder(e,env,dedicated)
 local list=builders(env);if #list==0 then builderPage=1 else builderPage=((builderPage-1)%#list)+1 end
 builderUI.paint(e,list[builderPage],builderPage,#list,{title=dedicated and"BUILDER / QUARRY"or"BUILDER / QUARRY"})
 if not dedicated then paintViewButton(e,"FLEET")end
end

function M.init(c)targets={};viewTargets={};lastRequest=nil;forgetRequest=nil;localMessage="";lastEnv,lastMeta=nil,nil;sharedView=nil;builderPage=1;return base.init and base.init(c)end
function M.render(env,meta)
 lastEnv,lastMeta=env,meta;viewTargets={};local ok=base.render(env,meta);local ms=monitors();local power=ms[2];local bs=builders(env);local dedicated=plannedBuilderMonitor(ms,env)
 -- Wide screens get the alpha81 three-column truth dashboard. Tall/narrow
 -- screens deliberately keep v27's proven vertical battery + Flux renderer.
 if power and power.w>=power.h*1.45 then renderPowerWide(power,env)end
 if ms[3]then
  if dedicated and#bs>0 then renderFleet(ms[3],env);renderBuilder(dedicated,env,true)
  elseif #bs>0 then
   sharedView=sharedView or"BUILDER"
   if sharedView=="BUILDER"then renderBuilder(ms[3],env,false)else renderFleet(ms[3],env);paintViewButton(ms[3],"BUILDER")end
  else sharedView="FLEET";renderFleet(ms[3],env)end
 end
 return ok
end
function M.onPeripheralChange(...)targets={};viewTargets={};if base.onPeripheralChange then return base.onPeripheralChange(...)end end
function M.handleEvent(ev,env,action)
 lastEnv=env or lastEnv
 if ev[1]=="monitor_touch"then
  local ms=monitors();local fm=ms[3];local bm=plannedBuilderMonitor(ms,lastEnv);local name,x,y=ev[2],tonumber(ev[3]),tonumber(ev[4]);local nav=viewTargets[name]
  if nav and x and y==nav.y and x>=nav.x1 and x<=nav.x2 then sharedView=nav.action;M.render(lastEnv,lastMeta);return true end
  local bs=builders(lastEnv);if#bs==0 then bm=nil end;local builderMon=bm or(fm and sharedView=="BUILDER"and fm or nil)
  if builderMon and name==builderMon.name then
   if #bs>1 and y==builderMon.h and x then builderPage=((builderPage-1+(x<=math.floor(builderMon.w/2)and-1 or 1))%#bs)+1;M.render(lastEnv,lastMeta)end
   return true
  end
  if fm and name==fm.name then
   localMessage=""
   for _,t in ipairs(targets[name]or{})do if y and y>=t.y1 and y<=t.y2 then
    if t.main then
     lastRequest=nil;forgetRequest=nil;localMessage="KIMI ID 1 IS MAIN SERVER - CANNOT FORGET"
    elseif t.status=="OFFLINE"then
     lastRequest=nil
     local stamp=now()
     if forgetRequest and sameId(forgetRequest.id,t.id)and stamp-forgetRequest.at<=6000 then
      local ok,res=pcall(action,"fleet_admin","forget",{id=t.id})
      forgetRequest=nil
      if ok and(type(res)~="table"or res.ok~=false)then localMessage="FORGETTING ID "..tostring(t.displayId).." - REBOOTING..."else localMessage="FORGET FAILED -> ID "..tostring(t.displayId)end
     else
      forgetRequest={id=t.id,at=stamp};localMessage="TAP ID "..tostring(t.displayId).." AGAIN TO FORGET"
     end
    else
     forgetRequest=nil
     local stamp=now();local ok,res=pcall(action,"server","identify",{id=t.id,duration=10});local sent=ok and type(res)=="table"and res.ok~=false
     if sent then lastRequest={id=t.id,displayId=t.displayId,at=stamp};localMessage=""else lastRequest=nil;localMessage="IDENTIFY SEND FAILED -> ID "..tostring(t.displayId)end
    end
    M.render(lastEnv,lastMeta);return true
   end end
   return true
  end
  if bm and name==bm.name then return true end
 end
 local handled=base.handleEvent and base.handleEvent(ev,env,action)or false;if handled then M.render(lastEnv,lastMeta)end;return handled
end
return M