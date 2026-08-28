-- Alpha81 operational-truth overlay.
-- Green means a real heartbeat arrived within the strict reachability window.
-- Remembered computers stay visible as OFFLINE instead of being hidden or
-- mislabeled LIVE. POWER likewise says telemetry is unavailable rather than
-- claiming a physical Matrix does not exist.
local base=require("clients.admin_v27")
local health=require("core.fleet_health")
local M={}
for k,v in pairs(base)do M[k]=v end

local C={bg=colors.black,text=colors.white,dim=colors.lightGray,good=colors.lime,warn=colors.orange,bad=colors.red,panel=colors.gray}
local lastEnv,lastMeta
local targets={}
local lastRequest=nil
local localMessage=""

local function upper(v)return tostring(v or""):upper()end
local function nice(v)return upper(tostring(v or""):gsub("minecraft:",""):gsub("[_%-]"," "):gsub("(%l)(%u)","%1 %2"))end
local function state(env)return env and env.state or{}end
local function now()
    if type(os.epoch)=="function"then local ok,v=pcall(os.epoch,"utc");if ok and tonumber(v)then return tonumber(v)end end
    local ok,t=pcall(os.time,"ingame");return math.floor((ok and tonumber(t)or 0)*1000)
end
local function gameTime()local ok,t=pcall(os.time,"ingame");t=ok and tonumber(t)or 0;local h=math.floor(t%24);local m=math.floor(((t%24)-h)*60+.5)%60;return string.format("%02d:%02d",h,m)end
local function sameId(a,b)return a~=nil and b~=nil and tostring(a)==tostring(b)end
local function fmt(n)
    local v=tonumber(n);if not v then return"?"end;local a=math.abs(v)
    if a>=1e15 then return string.format("%.1fP",v/1e15)elseif a>=1e12 then return string.format("%.1fT",v/1e12)elseif a>=1e9 then return string.format("%.1fG",v/1e9)elseif a>=1e6 then return string.format("%.1fM",v/1e6)elseif a>=1e3 then return string.format("%.1fK",v/1e3)end
    return tostring(math.floor(v+.5))
end
local function pct(p)
    local n=tonumber(p and p.filledPercentage);if n then if n<=1 then n=n*100 end;return math.max(0,math.min(100,n))end
    local s,c=tonumber(p and p.stored),tonumber(p and p.capacity);if s and c and c>0 then return math.max(0,math.min(100,s/c*100))end
end

local function isMonitor(n)
    local ok,t=pcall(peripheral.getType,n);if ok and t=="monitor"then return true end
    if type(peripheral.hasType)=="function"then local ok2,v=pcall(peripheral.hasType,n,"monitor");if ok2 and v then return true end end
    return false
end
local function monitors()
    local out={};local ok,names=pcall(peripheral.getNames);if not ok or type(names)~="table"then return out end
    for _,n in ipairs(names)do if isMonitor(n)then
        local okw,m=pcall(peripheral.wrap,n);if okw and m then
            local scale=1;pcall(m.setTextScale,scale);local oks,w,h=pcall(m.getSize)
            if oks then
                w,h=tonumber(w),tonumber(h)
                if w<22 or h<12 then scale=.5;pcall(m.setTextScale,scale);local ok2,w2,h2=pcall(m.getSize);if ok2 then w,h=tonumber(w2)or w,tonumber(h2)or h end end
                out[#out+1]={name=n,mon=m,w=w,h=h,area=w*h,scale=scale}
            end
        end
    end end
    table.sort(out,function(a,b)if a.area~=b.area then return a.area>b.area end;if a.w~=b.w then return a.w>b.w end;return a.name<b.name end)
    return out
end
local function prep(e)pcall(e.mon.setTextScale,e.scale);e.mon.setBackgroundColor(C.bg);e.mon.setTextColor(C.text);e.mon.clear()end
local function put(e,x,y,text,fg,bg)
    if not e or y<1 or y>e.h or x>e.w then return end
    x=math.max(1,x);text=tostring(text or"")
    e.mon.setCursorPos(x,y);e.mon.setBackgroundColor(bg or C.bg);e.mon.setTextColor(fg or C.text)
    e.mon.write(text:sub(1,math.max(0,e.w-x+1)));e.mon.setBackgroundColor(C.bg)
end
local function fill(e,x1,y1,x2,y2,bg)
    x1,x2=math.max(1,x1),math.min(e.w,x2);y1,y2=math.max(1,y1),math.min(e.h,y2)
    if x2<x1 or y2<y1 then return end
    for y=y1,y2 do put(e,x1,y,string.rep(" ",x2-x1+1),C.text,bg)end
end
local function rule(e,y)put(e,2,y,string.rep("-",math.max(0,e.w-2)),C.panel)end
local function header(e,title)
    put(e,2,1,title,C.text);put(e,math.max(2,e.w-6),1,gameTime(),C.dim)
    local label=(type(os.getComputerLabel)=="function"and os.getComputerLabel())or"MAIN BASE";put(e,2,2,upper(label),C.dim);rule(e,3)
end

local function fleetEntries(env)
    local st=state(env);local fleet=st.fleet or{};local serverId=env and env.serverId;local t=now()
    local out={};local counts={ONLINE=0,LATE=0,OFFLINE=0}
    for id,m in pairs(fleet)do
        local status,age=health.reachability(id,m,serverId,t)
        local main=sameId(id,serverId)
        if main then status="MAIN";counts.ONLINE=counts.ONLINE+1 else counts[status]=(counts[status]or 0)+1 end
        out[#out+1]={id=id,m=m or{},status=status,age=age,main=main}
    end
    table.sort(out,function(a,b)
        local rank={MAIN=0,ONLINE=1,LATE=2,OFFLINE=3};local ra,rb=rank[a.status]or 9,rank[b.status]or 9
        if ra~=rb then return ra<rb end
        local na,nb=upper(a.m.name or a.m.role or a.id),upper(b.m.name or b.m.role or b.id)
        if na~=nb then return na<nb end
        return tostring(a.id)<tostring(b.id)
    end)
    return out,counts,t
end

local function feedback(t)
    if localMessage~=""then return localMessage,C.warn end
    if not lastRequest then return"TOUCH ONLINE ROW -> FLASH THAT COMPUTER",C.dim end
    local acks=rawget(_G,"kimiIdentifyAck")or{};local ack=acks[tostring(lastRequest.id)]
    if type(ack)=="table"and tonumber(ack.at)and tonumber(ack.at)>=lastRequest.at then return"CONFIRMED ID "..tostring(lastRequest.id).." FLASHING",C.good end
    if t-lastRequest.at<3000 then return"WAITING FOR ID "..tostring(lastRequest.id).." ACK...",C.warn end
    return"ID "..tostring(lastRequest.id).." NOT REACHABLE",C.bad
end

local function renderFleet(e,env)
    prep(e);targets[e.name]={};header(e,"FLEET / IDENTIFY")
    local rows,c,t=fleetEntries(env)
    put(e,2,4,"VERSION "..tostring(env and env.version or"?"),C.dim)
    put(e,2,5,"ONLINE "..c.ONLINE.."  LATE "..c.LATE.."  OFFLINE "..c.OFFLINE,(c.LATE+c.OFFLINE)>0 and C.warn or C.good)
    local msg,fg=feedback(t);put(e,2,6,msg,fg);rule(e,7)
    if e.w>=42 then put(e,2,8,"GREEN = HEARTBEAT <= 6.5s   LATE <= 15s",C.dim)end
    local y=e.w>=42 and 10 or 9;local shown=0
    for _,row in ipairs(rows)do
        if y+1>e.h then break end
        local id,m,status=row.id,row.m,row.status
        local name=upper(m.name or m.role or("KIMI-"..tostring(id)))
        local fgStatus=status=="OFFLINE"and C.bad or(status=="LATE"and C.warn or C.good)
        put(e,2,y,"ID "..tostring(id).." "..name,C.text)
        put(e,math.max(2,e.w-#status-1),y,status,fgStatus)
        put(e,2,y+1,upper(m.role or"?").."  "..tostring(m.version or"?"),C.dim)
        local seen=row.main and"LOCAL"or("SEEN "..health.ageText(row.age))
        put(e,math.max(2,e.w-#seen-1),y+1,seen,status=="OFFLINE"and C.bad or C.dim)
        targets[e.name][#targets[e.name]+1]={y1=y,y2=y+1,id=tonumber(id)or id,main=row.main,status=status,age=row.age}
        y=y+3;shown=shown+1
    end
    if #rows>shown and e.h>=2 then put(e,2,e.h,"+"..tostring(#rows-shown).." MORE REMEMBERED",C.dim)end
end

local function sourcePowerInfo(env)
    local st=state(env);local t=now();local serverId=env and env.serverId;local out={}
    for id,s in pairs(st.sources or{})do
        local p=s.state and s.state.power
        local matrices=type(p)=="table"and p.matrices or nil
        local flux=type(p)=="table"and p.fluxNetworks or nil
        if type(matrices)=="table"and #matrices>0 or type(flux)=="table"and #flux>0 then
            local seen=s.lastHeartbeat or s.lastSeen
            local status,age=health.reachability(id,{lastSeen=seen},serverId,t)
            out[#out+1]={id=id,name=s.name or("KIMI-"..tostring(id)),status=status,age=age,matrices=matrices or{},flux=flux or{}}
        end
    end
    table.sort(out,function(a,b)return tostring(a.name)<tostring(b.name)end)
    return out
end
local function biggestMatrix(list)
    local best,cap=nil,-1
    for _,m in ipairs(list or{})do local c=tonumber(m.capacity)or 0;if c>cap then best,cap=m,c end end
    return best
end
local function offlineMatrixHint(env)
    local best=nil
    for _,s in ipairs(sourcePowerInfo(env))do
        if #s.matrices>0 and s.status~="ONLINE"then if not best or s.age<best.age then best=s end end
    end
    return best
end

local function renderPower(e,env)
    prep(e);header(e,"POWER / LIVE TELEMETRY")
    local st=state(env);local p=st.power or{};local matrices=p.matrices or{};local fx=p.fluxNetworks or{};local rs=st.power_reserve or{}
    local main=biggestMatrix(matrices);local mp=pct(main)
    local col=math.max(12,math.floor((e.w-6)/3));local a1=2;local a2=math.min(e.w-2,a1+col-1);local b1=a2+2;local b2=math.min(e.w-2,b1+col-1);local c1=b2+2

    put(e,a1,5,"MAIN MATRIX",C.dim)
    if main then
        put(e,a1,6,mp and string.format("%.1f%%",mp)or"LIVE",C.good)
        fill(e,a1,7,a2,7,C.panel);if mp then local n=math.floor((a2-a1+1)*mp/100+.5);if n>0 then fill(e,a1,7,a1+n-1,7,C.good)end end
        put(e,a1,9,"STORED "..fmt(main.stored).." FE",C.text)
        put(e,a1,10,"CAP "..fmt(main.capacity).." FE",C.dim)
        if e.h>=12 then put(e,a1,11,"IN  +"..fmt(main.input).."/t",C.good);put(e,a1,12,"OUT -"..fmt(main.output).."/t",C.dim)end
    else
        put(e,a1,6,"NO LIVE MATRIX TELEMETRY",C.bad)
        local hint=offlineMatrixHint(env)
        if hint then put(e,a1,8,upper(hint.name),C.warn);put(e,a1,9,"LAST SEEN "..health.ageText(hint.age),C.dim)else put(e,a1,8,"CHECK MATRIX NODE",C.warn)end
    end

    put(e,b1,5,"RESERVE",C.dim)
    if not main then
        put(e,b1,6,"WAITING FOR LIVE MAIN",C.warn)
    else
        local status=upper(rs.status or(rs.configured and"ARMED"or"NOT CONFIGURED"))
        if status=="NO MAIN MATRIX"then status="WAITING FOR TELEMETRY"end
        put(e,b1,6,status,rs.feeding and C.warn or(rs.configured and C.good or C.dim))
        if rs.reservePercent~=nil then put(e,b1,8,string.format("%.1f%%",tonumber(rs.reservePercent)or 0),C.good)elseif #matrices<2 then put(e,b1,8,"NO LIVE BACKUP MATRIX",C.dim)end
        put(e,b1,10,"FEED <= "..tostring(math.floor(tonumber(rs.lowPercent)or20)).."%",C.dim)
        if e.h>=11 then put(e,b1,11,"STOP >= "..tostring(math.floor(tonumber(rs.highPercent)or80)).."%",C.dim)end
    end

    put(e,c1,5,"FLUX NETWORKS",C.dim);put(e,c1,6,tostring(#fx),#fx>0 and C.good or C.bad)
    if #fx==0 then put(e,c1,8,"NO LIVE FLUX TELEMETRY",C.warn)else
        local y=8
        for i,n in ipairs(fx)do if y>e.h then break end
            put(e,c1,y,nice(n.networkName or n.name or n.peripheral or("NETWORK "..i)),C.text)
            if y+1<=e.h then put(e,c1,y+1,fmt(n.stored).." FE  NET "..fmt(n.net).."/t",C.dim)end
            y=y+2
        end
    end
end

function M.init(c)
    targets={};lastRequest=nil;localMessage="";lastEnv,lastMeta=nil,nil
    return base.init and base.init(c)
end

function M.render(env,meta)
    lastEnv,lastMeta=env,meta
    local ok=base.render(env,meta)
    local ms=monitors();if ms[2]then renderPower(ms[2],env)end;if ms[3]then renderFleet(ms[3],env)end
    return ok
end

function M.onPeripheralChange(...)
    targets={}
    if base.onPeripheralChange then return base.onPeripheralChange(...)end
end

function M.handleEvent(ev,env,action)
    lastEnv=env or lastEnv
    if ev[1]=="monitor_touch"then
        local ms=monitors();local fm=ms[3];local name,y=ev[2],tonumber(ev[4])
        if fm and name==fm.name then
            localMessage=""
            for _,t in ipairs(targets[name]or{})do
                if y and y>=t.y1 and y<=t.y2 then
                    if t.main then
                        lastRequest=nil;localMessage="THAT IS MAIN BASE - YOU ARE LOOKING AT IT"
                    elseif t.status=="OFFLINE"then
                        lastRequest=nil;localMessage="ID "..tostring(t.id).." OFFLINE - LAST SEEN "..health.ageText(t.age)
                    else
                        local stamp=now();local ok,res=pcall(action,"server","identify",{id=t.id,duration=10})
                        local sent=ok and type(res)=="table"and res.ok~=false
                        if sent then lastRequest={id=t.id,at=stamp};localMessage="" else lastRequest=nil;localMessage="IDENTIFY SEND FAILED -> ID "..tostring(t.id)end
                    end
                    M.render(lastEnv,lastMeta);return true
                end
            end
            return true
        end
    end
    local handled=base.handleEvent and base.handleEvent(ev,env,action)or false
    if handled then M.render(lastEnv,lastMeta)end
    return handled
end

return M
