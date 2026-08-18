local M = {}

local monitors = {}
local touchTargets = {}

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

local function button(mon,name,x1,y1,x2,y2,text,enabled)
    local w,h=mon.getSize()
    x1=math.max(1,x1); x2=math.min(w,x2); y1=math.max(1,y1); y2=math.min(h,y2)
    if x2<x1 or y2<y1 then return end
    local bg=enabled==false and colors.gray or colors.red
    for y=y1,y2 do put(mon,x1,y,string.rep(" ",x2-x1+1),colors.white,bg) end
    local tx=math.max(x1,math.floor((x1+x2-#text+1)/2))
    local ty=math.floor((y1+y2)/2)
    put(mon,tx,ty,text,colors.white,bg)
    local peripheralName=peripheral.getName(mon)
    if peripheralName then
        touchTargets[peripheralName]=touchTargets[peripheralName] or {}
        touchTargets[peripheralName][#touchTargets[peripheralName]+1]={name=name,x1=x1,y1=y1,x2=x2,y2=y2,enabled=enabled~=false}
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
        put(mon,mid+2,6,"SCHEMA",colors.lightGray); put(mon,mid+13,6,envelope and envelope.schema or "?")
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
    put(mon,2,14,"TARGET",colors.lightGray); put(mon,14,14,update.targetVersion or "none")
    local scadaText=scadaOnline.."/"..scadaTotal.." online"
    if scadaPending>0 then scadaText=scadaText.." / "..scadaPending.." update"..(scadaPending==1 and "" or "s") end
    put(mon,2,15,"SCADA",colors.lightGray); put(mon,14,15,scadaText,scadaPending>0 and colors.yellow or (scadaTotal>0 and colors.lime or colors.gray))

    local checking=tostring(update.lastResult or ""):lower()=="checking..."
    local bx1=math.max(36,math.floor(w*0.58)); local bx2=w-3
    if bx2-bx1>=20 then
        button(mon,"check_updates",bx1,10,bx2,12,checking and "CHECKING..." or "CHECK KIMI UPDATES",not checking)
        button(mon,"scada_update",bx1,14,bx2,15,scadaPending>0 and "UPDATE SCADA" or "SCADA CURRENT",scadaPending>0)
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
    local w,h=mon.getSize()
    if h>=13 and w>=28 then
        local checking=tostring(up.lastResult or ""):lower()=="checking..."
        button(mon,"check_updates",3,11,w-2,13,checking and "CHECKING..." or "CHECK FOR UPDATES",not checking)
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

local extraPanels={panelFleet,panelUpdates,panelSources,panelScada}

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
        if i==1 and w>=50 and h>=20 then
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
            elseif target.name=="scada_update" and action then
                action("server","scada_update",{})
            end
            return
        end
    end
end

return M
