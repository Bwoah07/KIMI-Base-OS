local monitorConfig = require("core.monitor_config")
local fleetDisplay = require("core.fleet_display")
local builderUI = require("clients.builder_dashboard")

local M = {}
local config = { assignments = {} }
local targets = {}
local builderPages = {}
local lastEnv, lastMeta
local fleetForgetRequest=nil
local fleetMessage=""

local C = {
    bg=colors.black, text=colors.white, dim=colors.lightGray,
    good=colors.lime, warn=colors.orange, bad=colors.red,
    panel=colors.gray, action=colors.blue
}

local function upper(v) return tostring(v or ""):upper() end
local function nice(v)
    return upper(tostring(v or ""):gsub("minecraft:",""):gsub("[_%-]"," "):gsub("(%l)(%u)","%1 %2"))
end
local function state(env) return env and env.state or {} end
local function now()
    if type(os.epoch)=="function" then local ok,v=pcall(os.epoch,"utc"); if ok and tonumber(v) then return tonumber(v) end end
    return 0
end
local function gameTime()
    local ok,t=pcall(os.time,"ingame"); t=ok and tonumber(t) or 0
    local h=math.floor(t%24); local m=math.floor((((t%24)-h)*60)+.5)%60
    return string.format("%02d:%02d",h,m),h
end
local function fmt(n)
    local v=tonumber(n); if not v then return "?" end
    local a=math.abs(v)
    if a>=1e15 then return string.format("%.1fP",v/1e15) end
    if a>=1e12 then return string.format("%.1fT",v/1e12) end
    if a>=1e9 then return string.format("%.1fG",v/1e9) end
    if a>=1e6 then return string.format("%.1fM",v/1e6) end
    if a>=1e3 then return string.format("%.1fK",v/1e3) end
    return tostring(math.floor(v+.5))
end
local function pct(p)
    local n=tonumber(p and p.filledPercentage)
    if n then if n<=1 then n=n*100 end; return math.max(0,math.min(100,n)) end
    local s,c=tonumber(p and p.stored),tonumber(p and p.capacity)
    if s and c and c>0 then return math.max(0,math.min(100,(s/c)*100)) end
end
local function duration(sec)
    sec=tonumber(sec); if not sec or sec<0 or sec~=sec then return "CALCULATING" end
    sec=math.floor(sec+.5); if sec<60 then return sec.."s" end
    local m=math.floor(sec/60); if m<60 then return string.format("%dm %02ds",m,sec%60) end
    local h=math.floor(m/60); if h<24 then return string.format("%dh %02dm",h,m%60) end
    return string.format("%dd %02dh",math.floor(h/24),h%24)
end

local function isMonitor(name)
    local ok,t=pcall(peripheral.getType,name); if ok and t=="monitor" then return true end
    if type(peripheral.hasType)=="function" then local ok2,v=pcall(peripheral.hasType,name,"monitor"); if ok2 and v then return true end end
    return false
end

function M.monitors()
    local out={}
    local ok,names=pcall(peripheral.getNames); if not ok or type(names)~="table" then return out end
    for _,name in ipairs(names) do
        if isMonitor(name) then
            local okw,mon=pcall(peripheral.wrap,name)
            if okw and mon then
                local scale=1; pcall(mon.setTextScale,scale)
                local oks,w,h=pcall(mon.getSize)
                if oks then
                    w,h=tonumber(w),tonumber(h)
                    if w<22 or h<12 then
                        scale=.5; pcall(mon.setTextScale,scale)
                        local ok2,w2,h2=pcall(mon.getSize); if ok2 then w,h=tonumber(w2)or w,tonumber(h2)or h end
                    end
                    out[#out+1]={name=name,mon=mon,w=w,h=h,scale=scale,area=w*h}
                end
            end
        end
    end
    table.sort(out,function(a,b) if a.area~=b.area then return a.area>b.area end; if a.w~=b.w then return a.w>b.w end; return a.name<b.name end)
    return out
end

local function prep(e)
    pcall(e.mon.setTextScale,e.scale); e.mon.setBackgroundColor(C.bg); e.mon.setTextColor(C.text); e.mon.clear()
end
local function put(e,x,y,text,fg,bg)
    if not e or y<1 or y>e.h or x>e.w then return end
    x=math.max(1,x); text=tostring(text or "")
    e.mon.setCursorPos(x,y); e.mon.setBackgroundColor(bg or C.bg); e.mon.setTextColor(fg or C.text)
    e.mon.write(text:sub(1,math.max(0,e.w-x+1))); e.mon.setBackgroundColor(C.bg)
end
local function fill(e,x1,y1,x2,y2,bg)
    x1,x2=math.max(1,x1),math.min(e.w,x2); y1,y2=math.max(1,y1),math.min(e.h,y2)
    if x2<x1 or y2<y1 then return end
    for y=y1,y2 do put(e,x1,y,string.rep(" ",x2-x1+1),C.text,bg) end
end
local function center(e,y,text,fg,bg,x1,x2)
    x1,x2=x1 or 1,x2 or e.w; local w=x2-x1+1; text=tostring(text or "")
    if #text>w then text=text:sub(1,w) end
    put(e,x1+math.max(0,math.floor((w-#text)/2)),y,text,fg,bg)
end
local function rule(e,y) put(e,2,y,string.rep("-",math.max(0,e.w-2)),C.panel) end
local function header(e,title)
    local tm=gameTime(); put(e,2,1,title,C.text); put(e,math.max(2,e.w-#tm-1),1,tm,C.dim)
    local label=(type(os.getComputerLabel)=="function" and os.getComputerLabel()) or "KIMI"
    put(e,2,2,upper(label),C.dim); rule(e,3)
end
local function reg(name,x1,y1,x2,y2,data)
    targets[name]=targets[name] or {}; data.x1=x1; data.y1=y1; data.x2=x2; data.y2=y2
    targets[name][#targets[name]+1]=data
end

local function doors(env) return (state(env).doors or {}).doors or {} end
local function builders(env) return (state(env).builder or {}).builders or {} end
local function sensors(env)
    local a=state(env).attachments or {}; local out,seen={},{}
    local function add(d)
        local k=tostring(d and d._source or "").."|"..tostring(d and(d.name or d.type)or"")
        if not seen[k] then seen[k]=true; out[#out+1]=d end
    end
    for _,d in ipairs(a.sensors or {}) do add(d) end
    for _,d in ipairs(a.devices or {}) do
        for _,cat in ipairs(d.categories or {}) do if cat=="sensor" or cat=="sensor_candidate" then add(d); break end end
    end
    table.sort(out,function(a,b)return tostring(a.reportedName or a.name or a.type)<tostring(b.reportedName or b.name or b.type)end)
    return out
end

local function mainMatrix(env)
    local p=state(env).power or {}; local best,score=nil,-1
    for _,m in ipairs(p.matrices or {}) do
        local live=upper(m._telemetryStatus or "LIVE")=="LIVE" and 1e30 or 0
        local s=live+(tonumber(m.capacity) or 0); if s>score then best,score=m,s end
    end
    return best or (p.matrices or {})[1]
end

local function powerStatus(p)
    local stored,cap=tonumber(p and p.stored),tonumber(p and p.capacity)
    local input,output=tonumber(p and p.input)or 0,tonumber(p and p.output)or 0
    local net=tonumber(p and p.net); if net==nil then net=input-output end
    local threshold=math.max(1,math.max(math.abs(input),math.abs(output),1)*.002)
    if math.abs(net)<=threshold then return "HOLDING" end
    if net>0 then
        if stored and cap and stored>=cap then return "FULL" end
        if stored and cap then return "FULL IN "..duration((cap-stored)/(net*20)) end
        return "CHARGING"
    end
    if stored and stored<=0 then return "EMPTY" end
    if stored then return "EMPTY IN "..duration(stored/((-net)*20)) end
    return "DRAINING"
end

local function renderOverview(e,env)
    prep(e); header(e,"KIMI OVERVIEW")
    local st=state(env); local tm,hour=gameTime(); local en=st.environment or {}; local ds=doors(env)
    local weather=upper(en.weather or "UNKNOWN"); local period=(hour<6 or hour>=18)and"NIGHT"or"DAY"
    center(e,5,tm,C.text); center(e,6,period.." / "..weather,weather:find("THUNDER",1,true)and C.bad or(weather:find("RAIN",1,true)and C.warn or C.good))
    local main=mainMatrix(env); local mp=pct(main); put(e,2,9,"POWER",C.dim); put(e,10,9,mp and string.format("%.1f%%",mp)or"NO MATRIX",mp and C.good or C.warn)
    local online=0; for _,m in pairs(st.fleet or {}) do if m.online==true or upper(m.presence)=="ONLINE" then online=online+1 end end
    put(e,2,11,"FLEET",C.dim); put(e,10,11,tostring(online).." ONLINE",C.good)
    local open=0; for _,d in ipairs(ds) do if d.open==true then open=open+1 end end
    put(e,2,13,"DOORS",C.dim); put(e,10,13,tostring(open).." OPEN / "..tostring(#ds),open>0 and C.warn or C.good)
    local bs=builders(env); put(e,2,15,"BUILDERS",C.dim); put(e,12,15,tostring(#bs),#bs>0 and C.good or C.dim)
    if e.h>=18 then put(e,2,18,"MANUAL SCREEN - RUN 'setup monitors' TO CHANGE",C.dim) end
end

local function renderDoors(e,env)
    prep(e); header(e,"DOORS"); targets[e.name]={}
    local list=doors(env); local y=5
    if #list==0 then center(e,7,"NO DOORS CONFIGURED",C.dim); return end
    for _,d in ipairs(list) do
        if y+2>e.h then break end
        local online=d.online~=false; local opened=d.open==true
        local status=not online and"OFFLINE"or(opened and"OPEN"or"CLOSED")
        put(e,2,y,upper(d.name or "DOOR"),C.text); put(e,math.max(2,e.w-#status-1),y,status,not online and C.bad or(opened and C.good or C.dim))
        local bg=not online and C.panel or(opened and C.warn or C.good)
        local label=not online and"OFFLINE"or(opened and"CLOSE DOOR"or"OPEN DOOR")
        fill(e,2,y+1,e.w-2,y+2,bg); center(e,y+1,label,not online and C.dim or C.bg,bg,2,e.w-2)
        if online then reg(e.name,2,y+1,e.w-2,y+2,{kind="door",door=d}) end
        y=y+4
    end
end

local function renderPower(e,env)
    prep(e); header(e,"POWER"); local p=state(env).power or {}; local main=mainMatrix(env); local mp=pct(main)
    center(e,5,"MAIN MATRIX",C.dim); center(e,6,mp and string.format("%.1f%%",mp)or"NO MATRIX",mp and C.good or C.warn)
    local x1,x2=2,e.w-2; fill(e,x1,8,x2,8,C.panel)
    if mp then local n=math.floor((x2-x1+1)*mp/100+.5); if n>0 then fill(e,x1,8,x1+n-1,8,C.good) end end
    center(e,10,powerStatus(main),C.text)
    put(e,2,12,"STORED "..fmt(main and main.stored).." FE",C.text)
    put(e,2,13,"IN  +"..fmt(main and main.input).." /t",C.good); put(e,2,14,"OUT -"..fmt(main and main.output).." /t",C.dim)
    local fx=p.fluxNetworks or {}; if e.h>=17 then rule(e,16); put(e,2,17,"FLUX NETWORKS "..#fx,#fx>0 and C.good or C.dim) end
    local y=18; for i,n in ipairs(fx) do if y>e.h then break end; put(e,2,y,nice(n.networkName or n.name or n.peripheral or("NETWORK "..i)),C.text); y=y+1 end
end

local function renderFleet(e,env)
    prep(e); header(e,"FLEET / IDENTIFY"); targets[e.name]={}
    local fleet=state(env).fleet or {}; local rows=fleetDisplay.rows(fleet,env and env.serverId)
    put(e,2,5,fleetMessage~="" and fleetMessage or "ONLINE: IDENTIFY / OFFLINE: TAP TWICE TO FORGET",fleetMessage~="" and C.warn or C.dim); local y=7
    for _,r in ipairs(rows) do
        if y+1>e.h then break end
        local main=r.main; local status=main and"MAIN"or upper(r.m.presence or(r.m.online==true and"ONLINE"or"OFFLINE")); local fg=status=="ONLINE"or status=="MAIN"and C.good or(status=="LATE"and C.warn or C.bad)
        local displayId=r.displayId or r.transportId
        put(e,2,y,"ID "..tostring(displayId).." "..upper(r.m.name or r.m.role or"KIMI"),C.text); put(e,math.max(2,e.w-#status-1),y,status,fg)
        put(e,2,y+1,upper(r.m.role or"?").."  "..tostring(r.m.version or"?"),C.dim)
        if not main then reg(e.name,2,y,e.w-2,y+1,{kind="fleet",id=r.transportId,displayId=displayId,status=status}) end
        y=y+3
    end
end

local function renderBuilder(e,env)
    targets[e.name]={}; local list=builders(env)
    if #list==0 then prep(e); header(e,"BUILDER / QUARRY"); center(e,7,"NO BUILDER DETECTED",C.dim); return end
    local page=builderPages[e.name] or 1; page=((page-1)%#list)+1; builderPages[e.name]=page
    builderUI.paint(e,list[page],page,#list,{title="BUILDER / QUARRY"})
    if #list>1 then
        put(e,2,e.h,"< PREV",C.dim); put(e,math.max(2,e.w-6),e.h,"NEXT >",C.dim)
        reg(e.name,1,e.h,math.floor(e.w/2),e.h,{kind="builder_prev"}); reg(e.name,math.floor(e.w/2)+1,e.h,e.w,e.h,{kind="builder_next"})
    end
end

local function renderWeather(e,env)
    prep(e); header(e,"WEATHER / TIME"); local en=state(env).environment or {}; local tm,hour=gameTime(); local period=(hour<6 or hour>=18)and"NIGHT"or"DAY"
    center(e,5,tm,C.text); center(e,7,period,period=="DAY"and C.good or C.dim)
    local weather=upper(en.weather or"UNKNOWN"); center(e,9,weather,weather:find("THUNDER",1,true)and C.bad or(weather:find("RAIN",1,true)and C.warn or C.good))
    if e.h>=12 then put(e,2,12,"MOON",C.dim); put(e,8,12,nice(en.moon or"UNKNOWN"),C.text) end
    if e.h>=14 then put(e,2,14,"LIGHT "..tostring(en.blockLight or"?").." / SKY "..tostring(en.skyLight or"?"),C.dim) end
end

local function renderSensors(e,env)
    prep(e); header(e,"SENSORS"); local ss=sensors(env); put(e,2,5,"DETECTED "..#ss,#ss>0 and C.good or C.warn)
    if #ss==0 then center(e,8,"NO SENSOR TELEMETRY",C.dim); return end
    local y=7
    for i,s in ipairs(ss) do
        if y+1>e.h then break end
        put(e,2,y,nice(s.reportedName or s.name or s.type or("SENSOR "..i)),C.text)
        local m=s.metrics or {}; local value=m.temperature or m.humidity or m.pressure or m.radiationRaw or m.onlinePlayers or m.playerCount or m.entityCount or s.summary or"ONLINE"
        put(e,2,y+1,tostring(value).."  "..upper(s._telemetryStatus or"LIVE"),upper(s._telemetryStatus or"LIVE")=="LIVE"and C.good or C.warn)
        y=y+3
    end
end

local function renderAE2(e,env)
    prep(e); header(e,"AE2 NETWORK"); local a=state(env).ae2 or {}; local online=a.online==true or upper(a._status)=="ONLINE"
    put(e,2,5,online and"ONLINE"or upper(a._status or"OFFLINE"),online and C.good or C.warn)
    if a.bridge then put(e,2,6,nice(a.bridge),C.dim) end
    put(e,2,9,"ITEMS",C.dim); put(e,2,10,fmt(a.itemCount or a.items).." / "..fmt(a.itemTypes).." TYPES",C.text)
    put(e,2,13,"STORAGE",C.dim); put(e,2,14,fmt(a.usedItemStorage).." / "..fmt(a.totalItemStorage),C.text)
    if e.h>=17 then put(e,2,17,"AE ENERGY",C.dim); put(e,2,18,fmt(a.storedEnergy).." / "..fmt(a.energyCapacity),C.text) end
end

local function renderSystem(e,env)
    prep(e); header(e,"KIMI SYSTEM"); local st=state(env); local total,online,late=0,0,0
    for _,m in pairs(st.fleet or {}) do total=total+1; local p=upper(m.presence or""); if m.online==true or p=="ONLINE" then online=online+1 elseif p=="LATE" then late=late+1 end end
    center(e,6,late==0 and"SYSTEMS NOMINAL"or"CHECK FLEET",late==0 and C.good or C.warn)
    put(e,2,9,"VERSION",C.dim); put(e,2,10,tostring(env and env.version or"?"),C.text)
    put(e,2,13,"FLEET "..online.." ONLINE / "..total.." TOTAL",C.good)
    put(e,2,15,"LATE "..late,late>0 and C.warn or C.dim)
    put(e,2,17,"SENSORS "..#sensors(env),C.dim); put(e,2,19,"DOORS "..#doors(env),C.dim); put(e,2,21,"BUILDERS "..#builders(env),C.dim)
end

local renderers={overview=renderOverview,doors=renderDoors,power=renderPower,fleet=renderFleet,builder=renderBuilder,weather=renderWeather,sensors=renderSensors,ae2=renderAE2,system=renderSystem}

function M.reload()
    local ok,data=pcall(monitorConfig.load); config=ok and data or {assignments={}}
    return config
end
function M.init()
    targets={}; builderPages={}; fleetForgetRequest=nil;fleetMessage="";lastEnv,lastMeta=nil,nil; M.reload()
end
function M.hasManualAssignments()
    for _,view in pairs(config.assignments or {}) do if monitorConfig.normalizeView(view)~="auto" then return true end end
    return false
end
function M.render(env,meta)
    lastEnv,lastMeta=env,meta; targets={}
    for _,e in ipairs(M.monitors()) do
        local view=monitorConfig.get(config,e.name)
        local fn=renderers[view]
        if view~="auto" and fn then fn(e,env) end
    end
    return true
end

local function hit(name,x,y)
    for _,t in ipairs(targets[name] or {}) do if x>=t.x1 and x<=t.x2 and y>=t.y1 and y<=t.y2 then return t end end
end

function M.handleEvent(ev,env,action)
    lastEnv=env or lastEnv
    if ev[1]~="monitor_touch" then return false end
    local name,x,y=ev[2],tonumber(ev[3]),tonumber(ev[4]); if not x or not y then return false end
    local view=monitorConfig.get(config,name); if view=="auto" then return false end
    local t=hit(name,x,y)
    if not t then return true end
    if t.kind=="door" then
        local d=t.door; if not d or d.online==false then return true end
        local cmd=d.open==true and"close"or"open"; local source=d._source or d.source or"server"
        local args={source=source,_source=source,target=d.target,side=d.side,id=d.id,key=d.key}
        local module=tostring(source)==tostring(os.getComputerID()) and"__local_doors"or"remote_doors_async"
        pcall(action,module,cmd,args)
    elseif t.kind=="fleet" then
        if t.status=="OFFLINE" then
            local stamp=now()
            if fleetForgetRequest and tostring(fleetForgetRequest.id)==tostring(t.id) and stamp-fleetForgetRequest.at<=6000 then
                fleetMessage="FORGETTING ID "..tostring(t.displayId).." - REBOOTING..."
                fleetForgetRequest=nil
                pcall(action,"fleet_admin","forget",{id=t.id})
            else
                fleetForgetRequest={id=t.id,at=stamp};fleetMessage="TAP ID "..tostring(t.displayId).." AGAIN TO FORGET"
            end
        else
            fleetForgetRequest=nil;fleetMessage=""
            pcall(action,"server","identify",{id=t.id,duration=10})
        end
    elseif t.kind=="identify" then
        pcall(action,"server","identify",{id=t.id,duration=10})
    elseif t.kind=="builder_prev" or t.kind=="builder_next" then
        local list=builders(lastEnv); if #list>0 then
            local p=builderPages[name] or 1; p=p+(t.kind=="builder_prev"and-1 or 1); builderPages[name]=((p-1)%#list)+1
        end
    end
    if lastEnv then M.render(lastEnv,lastMeta) end
    return true
end

return M