local M = {}

local monitors = {}
local touchTargets = {}
local monitorViews = {}

local function getMonitors()
    local out = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "monitor") then
            local mon = peripheral.wrap(name)
            if mon then out[#out + 1] = { name = name, mon = mon } end
        end
    end
    table.sort(out, function(a,b) return a.name < b.name end)
    return out
end

local function prep(mon)
    pcall(mon.setTextScale, 0.5)
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.white)
    mon.clear()
    mon.setCursorPos(1,1)
end

local function put(mon,x,y,text,color,bg)
    local w,h = mon.getSize()
    if y < 1 or y > h or x > w then return end
    text = tostring(text or "")
    if x < 1 then x = 1 end
    mon.setCursorPos(x,y)
    mon.setTextColor(color or colors.white)
    if bg then mon.setBackgroundColor(bg) end
    mon.write(text:sub(1, math.max(0,w-x+1)))
    if bg then mon.setBackgroundColor(colors.black) end
end

local function header(mon,title,right)
    local w = select(1,mon.getSize())
    mon.setBackgroundColor(colors.red)
    mon.setTextColor(colors.white)
    mon.setCursorPos(1,1)
    mon.write(string.rep(" ",w))
    local tx = math.max(1,math.floor((w-#title)/2)+1)
    mon.setCursorPos(tx,1)
    mon.write(title:sub(1,w))
    if right and #right+1 < w then
        mon.setCursorPos(math.max(1,w-#right),1)
        mon.write(right)
    end
    mon.setBackgroundColor(colors.black)
end

local function line(mon,y,label,value,color)
    label=tostring(label or ""); value=tostring(value or "")
    local text = label=="" and value or (label .. string.rep(" ",math.max(1,12-#label)) .. value)
    put(mon,2,y,text,color)
end

local function hline(mon,y,x1,x2,color)
    local w,h=mon.getSize(); if y<1 or y>h then return end
    x1=math.max(1,x1 or 1); x2=math.min(w,x2 or w)
    if x2<x1 then return end
    put(mon,x1,y,string.rep("-",x2-x1+1),color or colors.gray)
end

local function vline(mon,x,y1,y2,color)
    local w,h=mon.getSize(); if x<1 or x>w then return end
    y1=math.max(1,y1 or 1); y2=math.min(h,y2 or h)
    for y=y1,y2 do put(mon,x,y,"|",color or colors.gray) end
end

local function count(t) local n=0 for _ in pairs(t or {}) do n=n+1 end return n end
local function countOnline(t)
    local total,online=0,0
    for _,v in pairs(t or {}) do total=total+1 if v.online~=false then online=online+1 end end
    return online,total
end

local function age(ms)
    if not ms then return "never" end
    local n=tonumber(ms); if not n then return "?" end
    local d=math.max(0,math.floor((os.epoch("utc")-n)/1000))
    if d<60 then return d.."s ago" end
    if d<3600 then return math.floor(d/60).."m ago" end
    if d<86400 then return math.floor(d/3600).."h ago" end
    return math.floor(d/86400).."d ago"
end

local function fmtNumber(value)
    local n=tonumber(value)
    if not n then return "?" end
    local a=math.abs(n)
    if a>=1e12 then return string.format("%.2fT",n/1e12) end
    if a>=1e9 then return string.format("%.2fG",n/1e9) end
    if a>=1e6 then return string.format("%.2fM",n/1e6) end
    if a>=1e3 then return string.format("%.2fK",n/1e3) end
    return tostring(math.floor(n+0.5))
end

local function fmtFE(value,rate)
    local text=fmtNumber(value)
    return text=="?" and text or (text.." FE"..(rate and "/t" or ""))
end

local function percentOf(value)
    local n=tonumber(value)
    if not n then return nil end
    if n<=1 then n=n*100 end
    return math.max(0,math.min(100,n))
end

local function firstMatrix(power)
    return type(power)=="table" and type(power.matrices)=="table" and power.matrices[1] or nil
end

local function firstFlux(power)
    return type(power)=="table" and type(power.fluxNetworks)=="table" and power.fluxNetworks[1] or nil
end

local function shortDuration(seconds)
    seconds=math.max(0,math.floor(tonumber(seconds) or 0))
    local hours=math.floor(seconds/3600)
    local minutes=math.floor((seconds%3600)/60)
    if hours>0 then return tostring(hours).."h "..tostring(minutes).."m" end
    if minutes>0 then return tostring(minutes).."m "..tostring(seconds%60).."s" end
    return tostring(seconds).."s"
end

local function matrixState(matrix)
    local stored=tonumber(matrix and matrix.stored)
    local capacity=tonumber(matrix and matrix.capacity)
    local net=tonumber(matrix and matrix.net)
    if not stored or not capacity or capacity<=0 or not net then return "WAITING FOR COMPLETE MATRIX DATA",colors.yellow end
    if stored>=capacity*0.999999 and net>=-0.5 then return "FULL - HOLDING",colors.lime end
    if math.abs(net)<=0.5 then return "STABLE - HOLDING",colors.lightGray end
    if net>0 then return "CHARGING - FULL IN "..shortDuration((capacity-stored)/(net*20)),colors.lime end
    return "DRAINING - EMPTY IN "..shortDuration(stored/(math.abs(net)*20)),colors.orange
end

local function batteryColor(percent)
    if percent>=60 then return colors.lime end
    if percent>=25 then return colors.orange end
    return colors.red
end

local function drawBattery(mon,x1,y1,x2,y2,percent)
    local w,h=mon.getSize()
    x1=math.max(2,x1); x2=math.min(w-3,x2); y1=math.max(2,y1); y2=math.min(h-1,y2)
    if x2-x1<8 or y2-y1<3 then return false end
    percent=math.max(0,math.min(100,tonumber(percent) or 0))
    local inner=x2-x1-1
    local filled=math.floor(inner*percent/100+0.5)
    local fillColor=batteryColor(percent)

    put(mon,x1,y1,"+"..string.rep("-",inner).."+",colors.lightGray)
    for y=y1+1,y2-1 do
        put(mon,x1,y,"|",colors.lightGray)
        if filled>0 then put(mon,x1+1,y,string.rep(" ",filled),colors.black,fillColor) end
        if filled<inner then put(mon,x1+1+filled,y,string.rep(" ",inner-filled),colors.white,colors.black) end
        put(mon,x2,y,"|",colors.lightGray)
    end
    put(mon,x1,y2,"+"..string.rep("-",inner).."+",colors.lightGray)

    local capTop=math.max(y1+1,math.floor((y1+y2)/2)-1)
    if x2+2<=w then
        put(mon,x2+1,capTop,"  ",colors.black,colors.lightGray)
        put(mon,x2+1,capTop+1,"  ",colors.black,colors.lightGray)
    end

    local label=string.format("%.1f%%",percent)
    local labelX=math.max(x1+1,math.floor((x1+x2-#label+1)/2))
    local labelY=math.floor((y1+y2)/2)
    local labelInFill=(labelX+math.floor(#label/2)-x1)<=filled
    put(mon,labelX,labelY,label,labelInFill and colors.black or colors.white,labelInFill and fillColor or colors.black)
    return true
end

local function powerOnline(power)
    if type(power)~="table" or not power.sourceType then return false end
    local status=tostring(power._status or power.status or ""):lower()
    return status~="offline" and status~="error" and status~="disconnected"
end

local function uptime(startedAt)
    if not startedAt then return "?" end
    local d=math.max(0,math.floor((os.epoch("utc")-startedAt)/1000))
    local days=math.floor(d/86400); d=d%86400
    local h=math.floor(d/3600); local m=math.floor((d%3600)/60); local s=d%60
    if days>0 then return string.format("%dd %02dh %02dm",days,h,m) end
    if h>0 then return string.format("%dh %02dm %02ds",h,m,s) end
    if m>0 then return string.format("%dm %02ds",m,s) end
    return s.."s"
end

local function colorFor(v)
    v=tostring(v or ""):lower()
    if v=="online" or v=="up to date" or v=="ok" or v=="running" or v=="accepted" then return colors.lime end
    if v=="offline" or v:find("failed",1,true) or v:find("error",1,true) then return colors.red end
    return colors.yellow
end

local function sortedIds(t)
    local ids={}
    for id in pairs(t or {}) do ids[#ids+1]=id end
    table.sort(ids,function(a,b)
        local na,nb=tonumber(a),tonumber(b)
        if na and nb then return na<nb end
        return tostring(a)<tostring(b)
    end)
    return ids
end

local function moduleNames(state)
    local names={}
    for k in pairs(state or {}) do names[#names+1]=k end
    table.sort(names)
    return table.concat(names,",")
end

local function scadaSummary(sources)
    local online,total,pending=0,0,0
    for _,src in pairs(sources or {}) do
        if src.role=="scada" then
            total=total+1
            if src.online~=false then online=online+1 end
            local needs=false
            for _,value in pairs(src.state or {}) do
                if type(value)=="table" and value.updateAvailable==true then needs=true; break end
            end
            if needs then pending=pending+1 end
        end
    end
    return online,total,pending
end

local function button(mon,name,x1,y1,x2,y2,text,enabled,data,style)
    local w,h=mon.getSize()
    x1=math.max(1,x1); x2=math.min(w,x2); y1=math.max(1,y1); y2=math.min(h,y2)
    if x2<x1 or y2<y1 then return end
    local bg=enabled==false and colors.gray or (style and style.bg or colors.red)
    local fg=style and style.fg or colors.white
    for y=y1,y2 do put(mon,x1,y,string.rep(" ",x2-x1+1),fg,bg) end
    local tx=math.max(x1,math.floor((x1+x2-#text+1)/2))
    local ty=math.floor((y1+y2)/2)
    put(mon,tx,ty,text,fg,bg)
    local peripheralName=peripheral.getName(mon)
    if peripheralName then
        touchTargets[peripheralName]=touchTargets[peripheralName] or {}
        touchTargets[peripheralName][#touchTargets[peripheralName]+1]={name=name,x1=x1,y1=y1,x2=x2,y2=y2,enabled=enabled~=false,data=data}
    end
end

local function drawComposite(mon,envelope,meta)
    prep(mon)
    local w,h=mon.getSize()
    local machines=meta.machines or {}
    local sources=meta.sources or {}
    local update=meta.update or {}
    local online,total=countOnline(machines)
    local srcCount=count(sources)
    local scadaOnline,scadaTotal,scadaPending=scadaSummary(sources)
    local version=envelope and envelope.version or "?"
    local power=envelope and envelope.state and envelope.state.power or nil

    header(mon,"KIMI SERVER","#"..tostring(meta.serverId or "?"))

    put(mon,2,3,"STATUS",colors.lightGray); put(mon,14,3,"RUNNING",colors.lime)
    put(mon,2,4,"VERSION",colors.lightGray); put(mon,14,4,version,colors.white)
    put(mon,2,5,"UPTIME",colors.lightGray); put(mon,14,5,uptime(meta.startedAt),colors.white)

    local mid=math.max(34,math.floor(w*0.52))
    if mid < w-18 then
        vline(mon,mid,3,7,colors.gray)
        put(mon,mid+2,3,"FLEET",colors.lightGray); put(mon,mid+13,3,online.."/"..total.." online",online==total and colors.lime or colors.yellow)
        put(mon,mid+2,4,"SOURCES",colors.lightGray); put(mon,mid+13,4,srcCount,srcCount>0 and colors.lime or colors.yellow)
        put(mon,mid+2,5,"MONITORS",colors.lightGray); put(mon,mid+13,5,#monitors)
        put(mon,mid+2,6,"POWER",colors.lightGray); put(mon,mid+13,6,powerOnline(power) and fmtFE(power.stored,false) or "OFFLINE",powerOnline(power) and colors.lime or colors.red)
        put(mon,mid+2,7,"NETWORK",colors.lightGray); put(mon,mid+13,7,powerOnline(power) and (power.networkName or power.sourceType or "ONLINE") or "---",powerOnline(power) and colors.white or colors.gray)
    else
        put(mon,2,6,"FLEET",colors.lightGray); put(mon,14,6,online.."/"..total.." online")
        put(mon,2,7,"SOURCES",colors.lightGray); put(mon,14,7,srcCount)
    end

    hline(mon,8,2,w-1)

    put(mon,2,9,"UPDATE CONTROL",colors.lime)
    put(mon,2,10,"AUTHORITY",colors.lightGray); put(mon,14,10,"THIS SERVER",colors.lime)
    put(mon,2,11,"REMOTE",colors.lightGray); put(mon,14,11,update.remoteVersion or "unknown")
    put(mon,2,12,"LAST CHECK",colors.lightGray); put(mon,14,12,age(update.lastCheck))
    put(mon,2,13,"RESULT",colors.lightGray); put(mon,14,13,update.lastResult or "not checked",colorFor(update.lastResult))
    local fleetTracked=(tonumber(update.fleetCurrent) or 0)+(tonumber(update.fleetOutdated) or 0)
    put(mon,2,14,"FLEET OS",colors.lightGray); put(mon,14,14,tostring(update.fleetCurrent or 0).."/"..tostring(fleetTracked).." current",fleetTracked>0 and update.fleetOutdated==0 and colors.lime or colors.yellow)
    put(mon,2,15,"SYNC",colors.lightGray); put(mon,14,15,update.lastSync and age(update.lastSync) or "automatic",colors.lightGray)

    local checking=tostring(update.lastResult or ""):lower()=="checking..."
    local bx1=math.max(36,math.floor(w*0.58)); local bx2=w-3
    if bx2-bx1>=10 then
        button(mon,"check_updates",bx1,10,bx2,11,checking and "CHECKING" or "CHECK UPDATE",not checking)
        button(mon,"sync_fleet",bx1,12,bx2,13,"SYNC FLEET",true,nil,{bg=colors.orange,fg=colors.black})
        local split=math.floor((bx1+bx2)/2)
        button(mon,"matrix_panel",bx1,14,split-1,15,"PWR",true,nil,{bg=colors.lime,fg=colors.black})
        button(mon,"door_panel",split+1,14,bx2,15,"DOORS",true,nil,{bg=colors.gray,fg=colors.white})
    end

    if h < 18 then return end
    hline(mon,16,2,w-1)

    put(mon,2,17,"FLEET",colors.lime)
    put(mon,2,18,"ID",colors.gray)
    put(mon,9,18,"ROLE",colors.gray)
    put(mon,21,18,"VERSION",colors.gray)
    put(mon,42,18,"STATE",colors.gray)
    put(mon,51,18,"LAST SEEN",colors.gray)
    if w>=72 then put(mon,65,18,"UPDATE",colors.gray) end

    local y=19
    local fleetEnd=math.min(h-8,math.max(22,math.floor(h*0.68)))
    local ids=sortedIds(machines)
    if #ids==0 then
        put(mon,2,y,"No clients or nodes have checked in yet.",colors.yellow)
    else
        for _,id in ipairs(ids) do
            if y>fleetEnd then break end
            local m=machines[id]
            local isOn=m.online~=false
            put(mon,2,y,"#"..tostring(id),isOn and colors.lime or colors.red)
            put(mon,9,y,tostring(m.role or "?"),colors.white)
            put(mon,21,y,tostring(m.version or "?"),colors.white)
            put(mon,42,y,isOn and "ONLINE" or "OFFLINE",isOn and colors.lime or colors.red)
            put(mon,51,y,age(m.lastSeen),colors.lightGray)
            if w>=72 then put(mon,65,y,tostring(m.updateStatus or "-"),colorFor(m.updateStatus)) end
            y=y+1
        end
    end

    local teleY=fleetEnd+2
    if teleY<=h-4 then
        hline(mon,teleY,2,w-1); teleY=teleY+1
        put(mon,2,teleY,"TELEMETRY SOURCES",colors.lime); teleY=teleY+1
        local srcIds=sortedIds(sources)
        if #srcIds==0 then
            put(mon,2,teleY,"No remote telemetry sources online.",colors.yellow)
        else
            for _,id in ipairs(srcIds) do
                if teleY>h-2 then break end
                local s=sources[id]
                local isOn=s.online~=false
                put(mon,2,teleY,(isOn and "ON  " or "OFF ").."#"..tostring(id),isOn and colors.lime or colors.red)
                put(mon,14,teleY,tostring(s.role or "?").."  "..tostring(s.name or ""),colors.white)
                put(mon,36,teleY,moduleNames(s.state),colors.lightGray)
                teleY=teleY+1
            end
        end
    end

    if h>=3 then
        local problems={}
        if online<total then problems[#problems+1]=(total-online).." machine(s) offline" end
        if tostring(update.lastResult or ""):lower():find("failed",1,true) then problems[#problems+1]="update check failed" end
        if scadaPending>0 then problems[#problems+1]=scadaPending.." SCADA update(s) ready" end
        local footerY=h
        mon.setBackgroundColor(#problems==0 and colors.black or colors.red)
        mon.setTextColor(#problems==0 and colors.gray or colors.white)
        mon.setCursorPos(1,footerY)
        mon.write(string.rep(" ",w))
        mon.setCursorPos(2,footerY)
        if #problems==0 then mon.write("KIMI HEALTH: NOMINAL") else mon.write("ALERT: "..table.concat(problems," | ")) end
        mon.setBackgroundColor(colors.black)
    end
end

local function panelMatrixBattery(mon,envelope,meta,showBack)
    prep(mon); header(mon,"INDUCTION MATRIX")
    local power=envelope and envelope.state and envelope.state.power or {}
    local matrix=firstMatrix(power)
    local w,h=mon.getSize()
    local top=3
    if showBack then
        button(mon,"matrix_back",3,3,11,4,"BACK",true,nil,{bg=colors.gray})
        top=6
    end
    if not matrix then
        line(mon,top,"STATUS","NO MATRIX",colors.red)
        line(mon,top+2,"","Attach a Mekanism Induction Port",colors.yellow)
        line(mon,top+3,"","to any synced KIMI computer.",colors.lightGray)
        return
    end

    local percent=percentOf(matrix.filledPercentage)
    if not percent and tonumber(matrix.stored) and tonumber(matrix.capacity) and tonumber(matrix.capacity)>0 then
        percent=tonumber(matrix.stored)/tonumber(matrix.capacity)*100
    end
    percent=percent or 0
    local stateText,stateColor=matrixState(matrix)
    line(mon,top,"STATUS",stateText,stateColor)
    local batteryTop=top+2
    local batteryBottom=math.min(h-7,batteryTop+10)
    if batteryBottom-batteryTop<4 then batteryBottom=math.min(h-4,batteryTop+4) end
    drawBattery(mon,4,batteryTop,w-6,batteryBottom,percent)

    local y=batteryBottom+2
    line(mon,y,"STORED",fmtFE(matrix.stored,false)); y=y+1
    line(mon,y,"CAPACITY",fmtFE(matrix.capacity,false)); y=y+1
    line(mon,y,"FLOW","+"..fmtFE(matrix.input,true).."  -"..fmtFE(matrix.output,true)); y=y+1
    if y<=h then line(mon,y,"MATRIX","cells:"..tostring(matrix.installedCells or "?").." providers:"..tostring(matrix.installedProviders or "?"),colors.lightGray); y=y+1 end
    if y<=h then line(mon,y,"SOURCE",tostring(matrix._source or matrix.peripheral or "server"),colors.lightGray) end
end

local function panelPower(mon,envelope,meta)
    prep(mon)
    local allPower=envelope and envelope.state and envelope.state.power or {}
    local power=firstFlux(allPower)
    header(mon,"FLUX NETWORK")

    if not powerOnline(power) then
        line(mon,3,"STATUS","OFFLINE",colors.red)
        line(mon,5,"","Waiting for Flux Controller",colors.yellow)
        return
    end

    line(mon,3,"STATUS",power.status or "ONLINE",power.healthy==false and colors.yellow or colors.lime)
    line(mon,4,"NETWORK",power.networkName or "---",colors.white)
    hline(mon,5,2,select(1,mon.getSize())-1)
    line(mon,6,"STORED",fmtFE(power.stored,false))
    line(mon,7,"CAPACITY",fmtFE(power.capacity,false))
    line(mon,8,"INPUT",fmtFE(power.input,true),colors.lime)
    line(mon,9,"OUTPUT",fmtFE(power.output,true),colors.orange)
    line(mon,10,"NET",fmtFE(power.net,true),tonumber(power.net or 0)>=0 and colors.lime or colors.orange)

    line(mon,11,"DEVICES",power.deviceCount or "?")
    hline(mon,12,2,select(1,mon.getSize())-1)
    line(mon,13,"PLUGS",power.plugs or "?")
    line(mon,14,"POINTS",power.points or "?")
    line(mon,15,"STORAGES",power.storages or "?")
    line(mon,16,"CONTROLLERS",power.controllers or "?")
    line(mon,17,"WARNINGS",power.warningCount or 0,(power.warningCount or 0)>0 and colors.yellow or colors.lime)
    line(mon,18,"AVG TICK",power.avgTickUs and (string.format("%.1f",tonumber(power.avgTickUs)).." us/t") or "?")
    local _,h=mon.getSize()
    if h>=20 then line(mon,h-1,"SOURCE",power._source or power.peripheral or "server",colors.lightGray) end
end

local function panelPowerSources(mon,envelope)
    prep(mon); header(mon,"FLUX + MATRIX SOURCES")
    local power=envelope and envelope.state and envelope.state.power or {}
    local flux=power.fluxNetworks or {}; local matrices=power.matrices or {}; local detectors=power.energyDetectors or {}
    line(mon,3,"ONLINE",#flux+ #matrices + #detectors, (#flux+#matrices+#detectors)>0 and colors.lime or colors.red)
    line(mon,4,"FOUND","Flux:"..#flux.." Matrix:"..#matrices.." Detector:"..#detectors)
    hline(mon,5,2,select(1,mon.getSize())-1)
    local y=6; local _,h=mon.getSize()
    for _,value in ipairs(flux) do
        if y>h then break end
        line(mon,y,"FLUX",tostring(value.networkName or value.peripheral).."  "..fmtFE(value.stored,false),value.healthy==false and colors.yellow or colors.lime)
        y=y+1
        if y<=h then line(mon,y,"","+"..fmtFE(value.input,true).." -"..fmtFE(value.output,true).." dev:"..tostring(value.deviceCount or "?").." warn:"..tostring(value.warningCount or 0),colors.lightGray); y=y+1 end
    end
    for _,value in ipairs(matrices) do
        if y>h then break end
        line(mon,y,"MATRIX",tostring(value.peripheral).."  "..fmtFE(value.stored,false),colors.lime)
        y=y+1
        if y<=h then line(mon,y,"","+"..fmtFE(value.input,true).." -"..fmtFE(value.output,true).." cells:"..tostring(value.installedCells or "?"),colors.lightGray); y=y+1 end
    end
    for _,value in ipairs(detectors) do
        if y>h then break end
        line(mon,y,"DETECTOR",tostring(value.peripheral).."  "..fmtFE(value.transferRate,true),colors.lime); y=y+1
    end
    if y==6 then line(mon,7,"","Waiting for Flux Controller / Matrix",colors.yellow) end
end

local function panelAttachments(mon,envelope)
    prep(mon); header(mon,"ALL ATTACHMENTS")
    local value=envelope and envelope.state and envelope.state.attachments or {}
    local categories=value.categories or {}
    line(mon,3,"ATTACHED",value.count or 0,(value.count or 0)>0 and colors.lime or colors.yellow)
    line(mon,4,"KINDS","sensor:"..tostring(categories.sensor or 0).." power:"..tostring(categories.power or 0).." storage:"..tostring(categories.storage or 0))
    hline(mon,5,2,select(1,mon.getSize())-1)
    local y=6; local _,h=mon.getSize()
    for _,device in ipairs(value.devices or {}) do
        if y>h then break end
        line(mon,y,"",tostring(device.name).."  ["..tostring(device.type).."]",device.online==false and colors.red or colors.lime)
        y=y+1
        if y<=h then line(mon,y,"","src:"..tostring(device._source or "server").."  methods:"..tostring(device.methodCount or 0).."  "..tostring(device.summary or ""),colors.lightGray); y=y+1 end
    end
    if (value.count or 0)==0 then line(mon,7,"","No peripherals attached",colors.yellow) end
end

local function panelSensors(mon,envelope)
    prep(mon); header(mon,"ALL SENSORS")
    local value=envelope and envelope.state and envelope.state.attachments or {}
    line(mon,3,"SENSORS",value.sensorCount or 0,(value.sensorCount or 0)>0 and colors.lime or colors.yellow)
    hline(mon,4,2,select(1,mon.getSize())-1)
    local y=5; local _,h=mon.getSize()
    for _,device in ipairs(value.sensors or {}) do
        if y>h then break end
        line(mon,y,"",tostring(device.name).."  ["..tostring(device.type).."]",colors.lime); y=y+1
        if y<=h then line(mon,y,"",tostring(device.summary or "Attached").."  src:"..tostring(device._source or "server"),colors.lightGray); y=y+1 end
    end
    if (value.sensorCount or 0)==0 then line(mon,6,"","Attach any detector/scanner/reader",colors.yellow) end
end

local function panelDoors(mon,envelope,meta,showBack)
    prep(mon); header(mon,"DOOR CONTROL")
    local value=envelope and envelope.state and envelope.state.doors or {}
    local w,h=mon.getSize()
    local y=3
    if showBack then
        button(mon,"door_back",3,3,11,4,"BACK",true,nil,{bg=colors.gray})
        put(mon,14,3,tostring(value.controllerCount or 0).." controller(s)",colors.lightGray)
        y=6
    else
        line(mon,3,"CONTROL",tostring(value.controllerCount or 0).." / "..tostring(value.channelCount or 0).." channels")
        y=5
    end
    for _,controller in ipairs(value.controllers or {}) do
        if y>h then break end
        line(mon,y,"",tostring(controller.name).."  src:"..tostring(controller._source or "server"),colors.lime); y=y+1
        local channels=controller.channels or {}
        local columns=w>=66 and 6 or (w>=34 and 3 or 2)
        local gap=1
        local usable=w-4
        local cellWidth=math.floor((usable-gap*(columns-1))/columns)
        for index,channel in ipairs(channels) do
            local column=(index-1)%columns
            local row=math.floor((index-1)/columns)
            local buttonY=y+row
            if buttonY>h then break end
            local x1=3+column*(cellWidth+gap)
            local x2=x1+cellWidth-1
            local side=tostring(channel.label or channel.side or "door")
            local state=channel.open and "OPEN" or "SHUT"
            button(mon,"door_toggle",x1,buttonY,x2,buttonY,side:upper()..":"..state,true,{
                _source=controller._source or "server",
                target=controller.target,
                side=channel.side
            },channel.open and {bg=colors.lime,fg=colors.black} or {bg=colors.gray,fg=colors.white})
        end
        y=y+math.max(1,math.ceil(#channels/columns))+1
    end
    if (value.controllerCount or 0)==0 then line(mon,y,"","No redstone or door controller",colors.yellow) end
end

local function panelFleet(mon,envelope,meta)
    prep(mon); header(mon,"FLEET")
    local machines=meta.machines or {}; local ids=sortedIds(machines)
    local on,total=countOnline(machines)
    line(mon,3,"ONLINE",on.."/"..total,on==total and colors.lime or colors.yellow)
    hline(mon,4,2,select(1,mon.getSize())-1)
    local y=5; local _,h=mon.getSize()
    for _,id in ipairs(ids) do
        if y>h then break end
        local m=machines[id]; local st=m.online~=false and "ON" or "OFF"
        line(mon,y,"",st.." #"..id.." "..tostring(m.role or "?").." "..tostring(m.version or "?"),m.online~=false and colors.lime or colors.red)
        y=y+1
    end
    if #ids==0 then line(mon,6,"","No clients/nodes seen",colors.yellow) end
end

local function panelUpdates(mon,envelope,meta)
    prep(mon); header(mon,"UPDATES")
    local up=meta.update or {}
    line(mon,3,"LOCAL",envelope and envelope.version or "?")
    line(mon,4,"REMOTE",up.remoteVersion or "?")
    line(mon,5,"RESULT",up.lastResult or "not checked",colorFor(up.lastResult))
    line(mon,6,"CHECKED",age(up.lastCheck))
    line(mon,8,"TARGET",up.targetVersion or "none")
    line(mon,9,"AUTHORITY",up.authority or meta.serverId or "?")
    line(mon,10,"FLEET",tostring(up.fleetCurrent or 0).." current / "..tostring(up.fleetOutdated or 0).." updating / "..tostring(up.fleetOffline or 0).." offline")
    local w,h=mon.getSize()
    if h>=13 and w>=28 then
        local checking=tostring(up.lastResult or ""):lower()=="checking..."
        button(mon,"check_updates",3,12,w-2,14,checking and "CHECKING..." or "CHECK FOR UPDATES",not checking)
        if h>=18 then button(mon,"sync_fleet",3,16,w-2,18,"SYNC ALL COMPUTERS",true,nil,{bg=colors.orange,fg=colors.black}) end
    end
end

local function panelSources(mon,envelope,meta)
    prep(mon); header(mon,"TELEMETRY")
    local srcs=meta.sources or {}; local ids=sortedIds(srcs)
    line(mon,3,"SOURCES",#ids)
    local y=5; local _,h=mon.getSize()
    for _,id in ipairs(ids) do
        if y>h then break end
        local s=srcs[id]; local st=s.online==false and "OFF" or "ON"
        line(mon,y,"",st.." #"..id.." "..moduleNames(s.state),s.online==false and colors.red or colors.lime)
        y=y+1
    end
    if #ids==0 then line(mon,6,"","No remote telemetry",colors.yellow) end
end

local function panelScada(mon,envelope,meta)
    prep(mon); header(mon,"NUCLEAR / SCADA")
    local srcs=meta.sources or {}
    local on,total,pending=scadaSummary(srcs)
    line(mon,3,"SCADA",on.."/"..total.." online",on==total and total>0 and colors.lime or colors.yellow)
    line(mon,4,"UPDATES",pending,pending>0 and colors.yellow or colors.lime)
    hline(mon,5,2,select(1,mon.getSize())-1)
    local y=6; local _,h=mon.getSize()
    for _,id in ipairs(sortedIds(srcs)) do
        if y>h-4 then break end
        local src=srcs[id]
        if src.role=="scada" then
            local shown=false
            for _,value in pairs(src.state or {}) do
                if type(value)=="table" and value.app then
                    local state=value.updateAvailable and "UPDATE" or "CURRENT"
                    line(mon,y,"",tostring(value.app).."  "..tostring(value.installedVersion or "?").."  "..state,value.updateAvailable and colors.yellow or colors.lime)
                    y=y+1; shown=true; break
                end
            end
            if not shown then line(mon,y,"",tostring(src.name or id),colors.lightGray); y=y+1 end
        end
    end
    if total==0 then line(mon,7,"","Waiting for SCADA bridge nodes",colors.yellow) end
    local w2,h2=mon.getSize()
    if pending>0 and h2>=4 and w2>=28 then button(mon,"scada_update",3,h2-2,w2-2,h2,"UPDATE SCADA",true) end
end

local extraPanels={panelMatrixBattery,panelPower,panelPowerSources,panelAttachments,panelSensors,panelDoors,panelFleet,panelUpdates,panelSources,panelScada}

function M.init()
    monitors=getMonitors()
    term.clear(); term.setCursorPos(1,1)
    print("KIMI Command Center Admin UI")
    print("Monitors detected: "..tostring(#monitors))
end

function M.render(envelope,meta)
    monitors=getMonitors(); meta=meta or {}; touchTargets={}
    for i,entry in ipairs(monitors) do
        local w,h=entry.mon.getSize()
        if monitorViews[entry.name]=="doors" then
            panelDoors(entry.mon,envelope,meta,true)
        elseif monitorViews[entry.name]=="matrix" then
            panelMatrixBattery(entry.mon,envelope,meta,true)
        elseif i==1 and w>=50 and h>=20 then
            drawComposite(entry.mon,envelope,meta)
        else
            extraPanels[((i-2)%#extraPanels)+1](entry.mon,envelope,meta)
        end
    end
end

function M.onPeripheralChange() monitors=getMonitors(); touchTargets={} end

function M.handleEvent(e,envelope,action)
    if type(e)~="table" or e[1]~="monitor_touch" then return end
    local name,x,y=e[2],e[3],e[4]
    for _,target in ipairs(touchTargets[name] or {}) do
        if target.enabled and x>=target.x1 and x<=target.x2 and y>=target.y1 and y<=target.y2 then
            if target.name=="check_updates" and action then
                action("server","check_updates",{})
            elseif target.name=="sync_fleet" and action then
                action("server","sync_fleet",{})
            elseif target.name=="scada_update" and action then
                action("server","scada_update",{})
            elseif target.name=="matrix_panel" then
                monitorViews[name]="matrix"
            elseif target.name=="matrix_back" then
                monitorViews[name]=nil
            elseif target.name=="door_panel" then
                monitorViews[name]="doors"
            elseif target.name=="door_back" then
                monitorViews[name]=nil
            elseif target.name=="door_toggle" and action then
                action("doors","toggle",target.data or {})
            end
            return
        end
    end
end

return M

