local M = {}
local monitors = {}

local function getMonitors()
    local out = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "monitor") then
            local mon = peripheral.wrap(name)
            if mon then
                pcall(mon.setTextScale,0.5)
                local w,h=mon.getSize()
                out[#out+1] = { name=name, mon=mon, w=w, h=h, area=w*h }
            end
        end
    end
    table.sort(out,function(a,b)
        if a.area~=b.area then return a.area>b.area end
        return a.name<b.name
    end)
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
    mon.setCursorPos(2,y); mon.setBackgroundColor(colors.black); mon.setTextColor(color or colors.white); mon.write(text:sub(1,math.max(0,w-2)))
end

local function divider(mon,y)
    local w,h=mon.getSize(); if y>h then return end
    mon.setCursorPos(2,y); mon.setBackgroundColor(colors.black); mon.setTextColor(colors.gray); mon.write(string.rep("-",math.max(1,w-3)))
end

local function count(t) local n=0 for _ in pairs(t or {}) do n=n+1 end return n end
local function countOnline(t) local total,online=0,0 for _,v in pairs(t or {}) do total=total+1 if v.online~=false then online=online+1 end end return online,total end
local function gameTime() local t=os.time("ingame")%24 local h=math.floor(t) local m=math.floor((t-h)*60) return string.format("%02d:%02d",h,m) end
local function age(ms) if not ms then return "never" end local d=math.max(0,math.floor((os.epoch("utc")-tonumber(ms))/1000)) if d<60 then return d.."s" elseif d<3600 then return math.floor(d/60).."m" else return math.floor(d/3600).."h" end end
local function fmtDuration(sec) sec=math.max(0,math.floor(tonumber(sec) or 0)) local d=math.floor(sec/86400) local h=math.floor((sec%86400)/3600) local m=math.floor((sec%3600)/60) local s=sec%60 if d>0 then return string.format("%dd %02dh",d,h) elseif h>0 then return string.format("%dh %02dm",h,m) elseif m>0 then return string.format("%dm %02ds",m,s) else return s.."s" end end
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

local function batteryColor(pct)
    if pct>=60 then return colors.lime end
    if pct>=25 then return colors.yellow end
    return colors.red
end

local function verticalBattery(mon,x1,y1,width,height,pct)
    local w,h=mon.getSize()
    if width<5 or height<5 or x1<1 or y1<1 or x1+width-1>w or y1+height-1>h then return end
    pct=math.max(0,math.min(100,tonumber(pct) or 0))
    local c=batteryColor(pct)
    local innerW=width-2
    local innerH=height-2
    local fill=math.floor(innerH*pct/100+0.5)
    if pct>0 and fill<1 then fill=1 end

    mon.setBackgroundColor(colors.black); mon.setTextColor(colors.lightGray)
    mon.setCursorPos(x1,y1); mon.write("+"..string.rep("-",innerW).."+")
    for row=1,innerH do
        local yy=y1+row
        local fromBottom=innerH-row+1
        mon.setCursorPos(x1,yy); mon.setBackgroundColor(colors.black); mon.setTextColor(colors.lightGray); mon.write("|")
        mon.setBackgroundColor(fromBottom<=fill and c or colors.gray); mon.write(string.rep(" ",innerW))
        mon.setBackgroundColor(colors.black); mon.setTextColor(colors.lightGray); mon.write("|")
    end
    mon.setCursorPos(x1,y1+height-1); mon.setBackgroundColor(colors.black); mon.setTextColor(colors.lightGray); mon.write("+"..string.rep("-",innerW).."+")

    local label=string.format("%.2f%%",pct)
    local lx=x1+math.max(0,math.floor((width-#label)/2))
    local ly=math.max(2,y1-1)
    mon.setCursorPos(lx,ly); mon.setBackgroundColor(colors.black); mon.setTextColor(c); mon.write(label)
end

local function batteryStatus(p)
    local stored=tonumber(p and p.stored)
    local capacity=tonumber(p and p.capacity)
    local net=tonumber(p and p.net)
    if not stored or not capacity or capacity<=0 or not net then return "STATUS UNKNOWN",colors.yellow end
    local epsilon=0.5
    if stored>=capacity*0.999999 and net>=-epsilon then return "FULL - holding",colors.lime end
    if stored<=0 and net<=epsilon then return "EMPTY - holding",colors.red end
    if math.abs(net)<=epsilon then return "STABLE - holding",colors.lightGray end
    if net>0 then
        local seconds=math.max(0,capacity-stored)/(net*20)
        return "CHARGING - full in "..fmtDuration(seconds),colors.lime
    end
    local seconds=stored/(math.abs(net)*20)
    return "DRAINING - empty in "..fmtDuration(seconds),colors.orange
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
    prep(mon)
    local s=stateOf(envelope); local allPower=s.power or {}; local flux=allPower.fluxNetworks or {}; local matrices=allPower.matrices or {}; local p=matrices[1] or flux[1] or allPower
    local isFlux=p and p.sourceType=="flux_network"
    header(mon,"ENERGY COMMAND",gameTime())
    local w,h=mon.getSize()
    local divY=math.min(h-7,20)

    local powerStatus=tostring(p and (p._status or p.status) or ""):lower()
    if p and p.sourceType and powerStatus~="offline" and powerStatus~="error" and powerStatus~="disconnected" then
        local pct=percentOf(p.filledPercentage)
        if not pct and tonumber(p.stored) and tonumber(p.capacity) and tonumber(p.capacity)>0 then pct=tonumber(p.stored)/tonumber(p.capacity)*100 end
        line(mon,3,"POWER",p.healthy==false and "WARNING" or "ONLINE",p.healthy==false and colors.yellow or colors.lime)
        line(mon,4,"FOUND","Matrix:"..tostring(#matrices).." Flux:"..tostring(#flux),colors.lightGray)

        local gaugeX=3
        local gaugeY=6
        local gaugeW=12
        local gaugeH=math.min(12,math.max(5,divY-gaugeY))
        verticalBattery(mon,gaugeX,gaugeY,gaugeW,gaugeH,pct or 0)

        local statusText,statusCol=batteryStatus(p)
        local infoX=17
        local function info(y,label,value,color)
            if y>=divY then return end
            mon.setCursorPos(infoX,y); mon.setBackgroundColor(colors.black); mon.setTextColor(color or colors.white)
            local txt=tostring(label)..string.rep(" ",math.max(1,10-#tostring(label)))..tostring(value)
            mon.write(txt:sub(1,math.max(0,w-infoX+1)))
        end
        info(5,"STATUS",statusText,statusCol)
        info(6,"STORED",fmtFE(p.stored,false))
        info(7,"CAPACITY",fmtFE(p.capacity,false))
        info(8,"INPUT",fmtFE(p.input,true),colors.lime)
        info(9,"OUTPUT",fmtFE(p.output,true),colors.orange)
        if isFlux then
            info(10,"BUFFER",fmtFE(p.buffer,false))
            info(11,"NETWORK",p.networkName or "?")
            info(12,"DEVICES","P:"..tostring(p.plugs or "?").." PT:"..tostring(p.points or "?").." S:"..tostring(p.storages or "?").." C:"..tostring(p.controllers or "?"))
            info(13,"SECURITY",p.security or "?")
            info(14,"AVG TICK",p.avgTickUs and (string.format("%.1f",tonumber(p.avgTickUs)).." us/t") or "?")
        else
            info(10,"TRANSFER",fmtFE(p.transferCap,true))
            info(11,"CELLS",p.installedCells or "?")
            info(12,"MODE",p.mode or "?")
            info(13,"SOURCE",p._source or p.peripheral or "server",colors.lightGray)
        end
    else
        line(mon,3,"POWER","OFFLINE",colors.red)
        line(mon,5,"","Waiting for Flux / power peripheral",colors.lightGray)
    end

    if divY>=15 then divider(mon,divY) end
    local y=divY+1
    line(mon,y,"FLUX",tostring(#flux).." controller(s)",#flux>0 and colors.lime or colors.yellow); y=y+1
    for index,value in ipairs(flux) do
        if y>h then break end
        line(mon,y,"#"..tostring(index),tostring(value.networkName or value.peripheral).."  "..fmtFE(value.stored,false),value.healthy==false and colors.yellow or colors.lime); y=y+1
        if y<=h then line(mon,y,"","+"..fmtFE(value.input,true).."  -"..fmtFE(value.output,true).."  "..tostring(value.peripheral or "?"),colors.lightGray); y=y+1 end
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

local function panelUpdate(mon,envelope,meta)
    prep(mon); header(mon,"KIMI STATUS")
    meta=meta or {}
    local up=stateOf(envelope).update or {}; local serverVersion=envelope and envelope.version or "?"; local localVersion=meta.localVersion or "?"; local synced=serverVersion==localVersion
    line(mon,3,"LOCAL OS",localVersion,synced and colors.lime or colors.yellow); line(mon,4,"SERVER OS",serverVersion); line(mon,5,"SYNC",synced and "CURRENT" or "UPDATE REQUIRED",synced and colors.lime or colors.yellow); divider(mon,6)
    line(mon,7,"AUTHORITY",up.authority or "server"); line(mon,8,"LAST CHECK",age(up.lastCheck)); line(mon,9,"RESULT",up.lastResult or "not checked",statusColor(up.lastResult)); line(mon,10,"FLEET",tostring(up.fleetCurrent or 0).." current / "..tostring(up.fleetOutdated or 0).." updating / "..tostring(up.fleetOffline or 0).." offline")
end

local function panelPowerSources(mon,envelope)
    prep(mon); header(mon,"FLUX + MATRIX")
    local p=stateOf(envelope).power or {}; local flux=p.fluxNetworks or {}; local matrices=p.matrices or {}; local detectors=p.energyDetectors or {}
    line(mon,3,"ONLINE",#flux+#matrices+#detectors,(#flux+#matrices+#detectors)>0 and colors.lime or colors.red)
    line(mon,4,"FOUND","Flux:"..#flux.." Matrix:"..#matrices.." Detect:"..#detectors); divider(mon,5)
    local y=6; local _,h=mon.getSize()
    for _,v in ipairs(flux) do if y>h then break end line(mon,y,"FLUX",tostring(v.networkName or v.peripheral).." "..fmtFE(v.stored,false),v.healthy==false and colors.yellow or colors.lime); y=y+1 if y<=h then line(mon,y,"","+"..fmtFE(v.input,true).." -"..fmtFE(v.output,true).." warn:"..tostring(v.warningCount or 0),colors.lightGray); y=y+1 end end
    for _,v in ipairs(matrices) do if y>h then break end line(mon,y,"MATRIX",tostring(v.peripheral).." "..fmtFE(v.stored,false),colors.lime); y=y+1 if y<=h then line(mon,y,"","+"..fmtFE(v.input,true).." -"..fmtFE(v.output,true).." cells:"..tostring(v.installedCells or "?"),colors.lightGray); y=y+1 end end
    if y==6 then line(mon,7,"","Waiting for power peripherals",colors.yellow) end
end

local function panelAttachments(mon,envelope)
    prep(mon); header(mon,"ALL ATTACHMENTS")
    local a=stateOf(envelope).attachments or {}; local c=a.categories or {}
    line(mon,3,"ATTACHED",a.count or 0,(a.count or 0)>0 and colors.lime or colors.yellow)
    line(mon,4,"KINDS","S:"..tostring(c.sensor or 0).." P:"..tostring(c.power or 0).." C:"..tostring(c.control or 0).." ST:"..tostring(c.storage or 0)); divider(mon,5)
    local y=6; local _,h=mon.getSize()
    for _,v in ipairs(a.devices or {}) do if y>h then break end line(mon,y,"",tostring(v.name).." ["..tostring(v.type).."]",v.online==false and colors.red or colors.lime); y=y+1 if y<=h then line(mon,y,"",tostring(v.summary or "Attached").." src:"..tostring(v._source or "server"),colors.lightGray); y=y+1 end end
    if (a.count or 0)==0 then line(mon,7,"","No peripherals attached",colors.yellow) end
end

local function panelSensors(mon,envelope)
    prep(mon); header(mon,"ALL SENSORS")
    local a=stateOf(envelope).attachments or {}
    line(mon,3,"SENSORS",a.sensorCount or 0,(a.sensorCount or 0)>0 and colors.lime or colors.yellow); divider(mon,4)
    local y=5; local _,h=mon.getSize()
    for _,v in ipairs(a.sensors or {}) do if y>h then break end line(mon,y,"",tostring(v.name).." ["..tostring(v.type).."]",colors.lime); y=y+1 if y<=h then line(mon,y,"",tostring(v.summary or "Attached").." src:"..tostring(v._source or "server"),colors.lightGray); y=y+1 end end
    if (a.sensorCount or 0)==0 then line(mon,6,"","Waiting for detector/scanner/reader",colors.yellow) end
end

local function panelDoors(mon,envelope)
    prep(mon); header(mon,"CONFIGURED DOORS")
    local d=stateOf(envelope).doors or {}
    line(mon,3,"DOORS",tostring(d.doorCount or 0).." configured / "..tostring(d.candidateCount or 0).." candidates"); divider(mon,4)
    local y=5; local _,h=mon.getSize()
    for _,door in ipairs(d.doors or {}) do
        if y>h then break end
        line(mon,y,"",tostring(door.name or ("DOOR "..tostring(door.id or "?"))).."  "..(door.online==false and "OFFLINE" or (door.open and "OPEN" or "CLOSED")),door.online==false and colors.red or (door.open and colors.lime or colors.lightGray)); y=y+1
    end
    if (d.doorCount or 0)==0 then line(mon,6,"","Add doors explicitly at the main Command Center",colors.yellow) end
end

local panels={panelOperations,panelOverview,panelSensors,panelEnvironment,panelPowerSources,panelAttachments,panelDoors,panelFleet,panelUpdate,panelSources,panelSystem,panelNetwork,panelModules}

function M.init() monitors=getMonitors(); term.clear(); term.setCursorPos(1,1); print("KIMI Wall Client"); print("Monitors detected: "..tostring(#monitors)) end
function M.render(envelope,meta) monitors=getMonitors(); meta=meta or {}; for i,entry in ipairs(monitors) do panels[((i-1)%#panels)+1](entry.mon,envelope,meta) end end
function M.onPeripheralChange() monitors=getMonitors() end
function M.handleEvent() end
return M

