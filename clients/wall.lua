local M = {}
local monitors = {}

local function getMonitors()
    local out = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "monitor") then
            local mon = peripheral.wrap(name)
            if mon then out[#out+1] = { name=name, mon=mon } end
        end
    end
    table.sort(out,function(a,b) return a.name<b.name end)
    return out
end

local function prep(mon)
    pcall(mon.setTextScale,0.5)
    mon.setBackgroundColor(colors.black); mon.setTextColor(colors.white); mon.clear(); mon.setCursorPos(1,1)
end

local function header(mon,title,right)
    local w=select(1,mon.getSize())
    mon.setBackgroundColor(colors.red); mon.setTextColor(colors.white); mon.setCursorPos(1,1); mon.write(string.rep(" ",w))
    mon.setCursorPos(math.max(1,math.floor((w-#title)/2)+1),1); mon.write(title:sub(1,w))
    if right and #right+1<w then mon.setCursorPos(math.max(1,w-#right),1); mon.write(right) end
    mon.setBackgroundColor(colors.black)
end

local function line(mon,y,label,value,color)
    local w,h=mon.getSize(); if y>h then return end
    label=tostring(label or ""); value=tostring(value or "")
    local text=label=="" and value or (label..string.rep(" ",math.max(1,11-#label))..value)
    mon.setCursorPos(2,y); mon.setTextColor(color or colors.white); mon.write(text:sub(1,math.max(0,w-2)))
end

local function divider(mon,y)
    local w,h=mon.getSize(); if y>h then return end
    mon.setCursorPos(2,y); mon.setTextColor(colors.gray); mon.write(string.rep("-",math.max(1,w-3)))
end

local function count(t) local n=0 for _ in pairs(t or {}) do n=n+1 end return n end
local function countOnline(t) local total,online=0,0 for _,v in pairs(t or {}) do total=total+1 if v.online~=false then online=online+1 end end return online,total end
local function gameTime() local t=os.time("ingame")%24 local h=math.floor(t) local m=math.floor((t-h)*60) return string.format("%02d:%02d",h,m) end
local function age(ms) if not ms then return "never" end local d=math.max(0,math.floor((os.epoch("utc")-tonumber(ms))/1000)) if d<60 then return d.."s" elseif d<3600 then return math.floor(d/60).."m" else return math.floor(d/3600).."h" end end
local function fmtDuration(sec) sec=math.max(0,math.floor(tonumber(sec) or 0)) local h=math.floor(sec/3600) local m=math.floor((sec%3600)/60) local s=sec%60 if h>0 then return string.format("%dh %02dm",h,m) elseif m>0 then return string.format("%dm %02ds",m,s) else return s.."s" end end
local function statusColor(status) status=tostring(status or ""):lower() if status=="online" or status=="ok" or status=="sunny" or status=="up to date" then return colors.lime end if status=="offline" or status=="error" or status:find("failed",1,true) then return colors.red end return colors.yellow end
local function stateOf(envelope) return envelope and envelope.state or {} end

local function fmtNumber(n)
    n=tonumber(n); if not n then return "?" end
    local a=math.abs(n)
    if a>=1e12 then return string.format("%.2fT",n/1e12) end
    if a>=1e9 then return string.format("%.2fG",n/1e9) end
    if a>=1e6 then return string.format("%.2fM",n/1e6) end
    if a>=1e3 then return string.format("%.2fK",n/1e3) end
    return tostring(math.floor(n+0.5))
end

local function fmtFE(n,rate)
    local s=fmtNumber(n)
    if s=="?" then return s end
    return s.." FE"..(rate and "/t" or "")
end

local function percentOf(p)
    p=tonumber(p)
    if not p then return nil end
    if p<=1 then p=p*100 end
    return math.max(0,math.min(100,p))
end

local function bar(mon,y,pct)
    local w,h=mon.getSize(); if y>h then return end
    local inner=math.max(8,w-6)
    pct=math.max(0,math.min(100,tonumber(pct) or 0))
    local fill=math.floor(inner*pct/100+0.5)
    if pct>0 and fill<1 then fill=1 end
    local c = pct >= 60 and colors.lime or (pct >= 25 and colors.yellow or colors.red)
    mon.setCursorPos(2,y); mon.setTextColor(colors.lightGray); mon.write("[")
    mon.setTextColor(c); mon.write(string.rep("#",fill))
    mon.setTextColor(colors.gray); mon.write(string.rep(".",inner-fill))
    mon.setTextColor(colors.lightGray); mon.write("]")
end

local function panelOverview(mon,envelope,meta)
    prep(mon); header(mon,"KIMI BASE",gameTime())
    local s=stateOf(envelope); local fo,ft=countOnline(s.fleet); local env=s.environment; local sys=s.system
    line(mon,3,"LINK",meta.connected and "SERVER ONLINE" or "SEARCHING",meta.connected and colors.lime or colors.yellow)
    line(mon,4,"SERVER",meta.serverId or "---"); line(mon,5,"VERSION",envelope and envelope.version or "?"); divider(mon,6)
    line(mon,7,"WEATHER",env and env.weather or "NO SENSOR",env and statusColor(env.weather) or colors.yellow)
    line(mon,8,"BIOME",env and env.biome or "---"); line(mon,9,"DIMENSION",env and env.dimension or "---"); line(mon,10,"MOON",env and env.moon or "---"); divider(mon,11)
    line(mon,12,"FLEET",fo.."/"..ft.." online"); line(mon,13,"SOURCES",count(s.sources)); line(mon,14,"CLIENT",os.getComputerID()); if sys then line(mon,15,"DAY",sys.ingameDay or "?") end
end

local function panelEnvironment(mon,envelope)
    prep(mon); header(mon,"ENVIRONMENT",gameTime())
    local env=stateOf(envelope).environment
    if not env then line(mon,3,"STATUS","WAITING FOR SENSOR",colors.yellow); return end
    line(mon,3,"STATUS",env._status or (env.online and "online" or "offline"),statusColor(env._status or (env.online and "online" or "offline")))
    line(mon,4,"WEATHER",env.weather or "UNKNOWN",statusColor(env.weather)); line(mon,5,"BIOME",env.biome or "UNKNOWN"); line(mon,6,"DIMENSION",env.dimension or "UNKNOWN"); divider(mon,7)
    line(mon,8,"SKY LIGHT",env.skyLight or "?"); line(mon,9,"BLOCK LIGHT",env.blockLight or "?"); line(mon,10,"MOON",env.moon or "UNKNOWN"); divider(mon,11)
    line(mon,12,"SENSOR",env.sensor or "unknown"); line(mon,13,"SOURCE",env._source or "server"); line(mon,14,"AGE",age(env._updated))
end

local function panelOperations(mon,envelope)
    prep(mon); header(mon,"POWER + STORAGE")
    local s=stateOf(envelope); local p=s.power; local ae=s.ae2 or s.storage

    if p and (p.status=="ONLINE" or p._status=="online") then
        local pct=percentOf(p.filledPercentage)
        if not pct and tonumber(p.stored) and tonumber(p.capacity) and tonumber(p.capacity)>0 then pct=tonumber(p.stored)/tonumber(p.capacity)*100 end
        line(mon,3,"POWER","ONLINE",colors.lime)
        line(mon,4,"CHARGE",pct and string.format("%.2f%%",pct) or "?")
        bar(mon,5,pct or 0)
        line(mon,7,"STORED",fmtFE(p.stored,false).." / "..fmtFE(p.capacity,false))
        line(mon,8,"INPUT",fmtFE(p.input,true),colors.lime)
        line(mon,9,"OUTPUT",fmtFE(p.output,true),colors.orange)
        local net=tonumber(p.net)
        line(mon,10,"NET",net and ((net>=0 and "+" or "")..fmtFE(net,true)) or "?",net and (net>=0 and colors.lime or colors.red) or colors.white)
        line(mon,11,"TRANSFER",fmtFE(p.transferCap,true))
        line(mon,12,"CELLS",p.installedCells or "?")
        line(mon,13,"MODE",p.mode or "?")
        line(mon,14,"SOURCE",p._source or p.peripheral or "server",colors.lightGray)
    else
        line(mon,3,"POWER","OFFLINE",colors.red)
        line(mon,5,"","Waiting for Induction Port",colors.lightGray)
    end

    divider(mon,16)
    if ae and ae._status=="online" then
        line(mon,17,"AE2","ONLINE",colors.lime)
        line(mon,18,"ITEMS",fmtNumber(ae.items))
        line(mon,19,"TYPES",ae.itemTypes or "?")
        line(mon,20,"CRAFTING",ae.craftingJobs or 0)
        line(mon,21,"STORAGE",ae.usedItemStorage and (fmtNumber(ae.usedItemStorage).." / "..fmtNumber(ae.totalItemStorage)) or "?")
        line(mon,22,"POWER",fmtFE(ae.storedEnergy,false))
        line(mon,23,"SOURCE",ae._source or "server",colors.lightGray)
    else
        line(mon,17,"AE2",ae and tostring(ae._status or "offline") or "WAITING",colors.yellow)
    end
end

local function panelFleet(mon,envelope)
    prep(mon); header(mon,"KIMI FLEET")
    local fleet=stateOf(envelope).fleet or {}; local ids={} for id in pairs(fleet) do ids[#ids+1]=id end table.sort(ids,function(a,b) return (tonumber(a) or 0)<(tonumber(b) or 0) end)
    local online,total=countOnline(fleet); line(mon,3,"ONLINE",online.."/"..total,online==total and colors.lime or colors.yellow); divider(mon,4)
    local y=5; local _,h=mon.getSize(); for _,id in ipairs(ids) do if y>h then break end local m=fleet[id]; local st=m.online~=false and "ON" or "OFF" line(mon,y,"",st.." #"..tostring(id).." "..tostring(m.role or "?").." "..tostring(m.version or "?"),m.online~=false and colors.lime or colors.red); y=y+1 end
end

local function panelSources(mon,envelope)
    prep(mon); header(mon,"TELEMETRY SOURCES")
    local sources=stateOf(envelope).sources or {}; local ids={} for id in pairs(sources) do ids[#ids+1]=id end table.sort(ids); line(mon,3,"SOURCES",#ids); divider(mon,4)
    local y=5; local _,h=mon.getSize(); for _,id in ipairs(ids) do if y>h then break end local src=sources[id]; local st=src.online==false and "OFF" or "ON" line(mon,y,"",st.." #"..tostring(id).." "..tostring(src.role or "?").." / "..count(src.state).." modules",src.online==false and colors.red or colors.lime); y=y+1 end
end

local function panelSystem(mon,envelope,meta)
    prep(mon); header(mon,"SYSTEM")
    local s=stateOf(envelope); local sys=s.system
    line(mon,3,"CLIENT ID",os.getComputerID()); line(mon,4,"LABEL",os.getComputerLabel() or "none"); line(mon,5,"SERVER",meta.serverId or "---"); line(mon,6,"LINK",meta.connected and "ONLINE" or "OFFLINE",meta.connected and colors.lime or colors.red); divider(mon,7)
    line(mon,8,"MONITORS",#monitors); line(mon,9,"VERSION",envelope and envelope.version or "?")
    if sys then line(mon,10,"GAME DAY",sys.ingameDay or "?"); line(mon,11,"GAME TIME",gameTime()); line(mon,12,"UPTIME",fmtDuration(sys.uptime)); line(mon,13,"PERIPHERALS",type(sys.peripherals)=="table" and #sys.peripherals or "?"); line(mon,14,"SOURCE",sys._source or "server") end
end

local function panelNetwork(mon,envelope,meta)
    prep(mon); header(mon,"NETWORK")
    local s=stateOf(envelope); local online,total=countOnline(s.fleet)
    line(mon,3,"PROTOCOL","kimi_base_os_v1"); line(mon,4,"SERVER",meta.serverId or "---"); line(mon,5,"STATE",meta.connected and "CONNECTED" or "SEARCHING",meta.connected and colors.lime or colors.yellow); divider(mon,6)
    line(mon,7,"FLEET",online.."/"..total.." online"); line(mon,8,"SOURCES",count(s.sources)); line(mon,9,"SCHEMA",envelope and envelope.schema or "?"); line(mon,10,"STATE AGE",envelope and age(envelope.generated) or "never")
end

local function panelModules(mon,envelope)
    prep(mon); header(mon,"MODULE HEALTH")
    local s=stateOf(envelope); local ignored={sources=true,fleet=true,update=true}; local names={} for id,v in pairs(s) do if not ignored[id] and type(v)=="table" then names[#names+1]=id end end table.sort(names)
    line(mon,3,"MODULES",#names); divider(mon,4); local y=5; local _,h=mon.getSize(); for _,id in ipairs(names) do if y>h then break end local v=s[id]; local st=v._status or (v.online==false and "offline" or "online") line(mon,y,"",string.upper(id).."  "..tostring(st).."  "..age(v._updated),statusColor(st)); y=y+1 end
end

local function panelUpdate(mon,envelope)
    prep(mon); header(mon,"KIMI STATUS")
    local up=stateOf(envelope).update or {}; line(mon,3,"SERVER OS",envelope and envelope.version or "?"); line(mon,4,"AUTHORITY",up.authority or "server"); divider(mon,5); line(mon,6,"LAST CHECK",age(up.lastCheck)); line(mon,7,"RESULT",up.lastResult or "not checked",statusColor(up.lastResult)); line(mon,8,"REMOTE",up.remoteVersion or "?"); line(mon,9,"TARGET",up.targetVersion or "none")
end

local panels={panelOverview,panelEnvironment,panelOperations,panelFleet,panelSources,panelSystem,panelNetwork,panelModules,panelUpdate}

function M.init() monitors=getMonitors(); term.clear(); term.setCursorPos(1,1); print("KIMI Wall Client"); print("Monitors detected: "..tostring(#monitors)) end
function M.render(envelope,meta) monitors=getMonitors(); meta=meta or {}; for i,entry in ipairs(monitors) do panels[((i-1)%#panels)+1](entry.mon,envelope,meta) end end
function M.onPeripheralChange() monitors=getMonitors() end
function M.handleEvent() end
return M
