local M = {}

local monitors = {}

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

local function header(mon,title,right)
    local w = select(1,mon.getSize())
    mon.setBackgroundColor(colors.red)
    mon.setTextColor(colors.white)
    mon.setCursorPos(1,1)
    mon.write(string.rep(" ",w))
    mon.setCursorPos(math.max(1,math.floor((w-#title)/2)+1),1)
    mon.write(title:sub(1,w))
    if right and #right+1<w then mon.setCursorPos(w-#right,1); mon.write(right) end
    mon.setBackgroundColor(colors.black)
end

local function line(mon,y,label,value,color)
    local w,h=mon.getSize(); if y>h then return end
    label=tostring(label or ""); value=tostring(value or "")
    local text = label=="" and value or (label .. string.rep(" ",math.max(1,12-#label)) .. value)
    mon.setCursorPos(2,y); mon.setTextColor(color or colors.white); mon.write(text:sub(1,math.max(0,w-2)))
end

local function divider(mon,y)
    local w,h=mon.getSize(); if y>h then return end
    mon.setCursorPos(2,y); mon.setTextColor(colors.gray); mon.write(string.rep("-",math.max(1,w-3)))
end

local function count(t) local n=0 for _ in pairs(t or {}) do n=n+1 end return n end
local function countOnline(t)
    local total,online=0,0
    for _,v in pairs(t or {}) do total=total+1 if v.online~=false then online=online+1 end end
    return online,total
end

local function age(ms)
    if not ms then return "never" end
    local d=math.max(0,math.floor((os.epoch("utc")-tonumber(ms))/1000))
    if d<60 then return d.."s ago" end
    if d<3600 then return math.floor(d/60).."m ago" end
    return math.floor(d/3600).."h ago"
end

local function uptime(startedAt)
    if not startedAt then return "?" end
    local d=math.max(0,math.floor((os.epoch("utc")-startedAt)/1000))
    local h=math.floor(d/3600); local m=math.floor((d%3600)/60); local s=d%60
    if h>0 then return string.format("%dh %02dm",h,m) end
    if m>0 then return string.format("%dm %02ds",m,s) end
    return s.."s"
end

local function colorFor(v)
    v=tostring(v or ""):lower()
    if v=="online" or v=="up to date" or v=="ok" or v=="running" then return colors.lime end
    if v=="offline" or v:find("failed",1,true) then return colors.red end
    return colors.yellow
end

local function panelServer(mon,envelope,meta)
    prep(mon); header(mon,"KIMI SERVER","#"..tostring(meta.serverId or "?"))
    local machines=meta.machines or {}; local sources=meta.sources or {}; local on,total=countOnline(machines)
    line(mon,3,"STATUS","RUNNING",colors.lime)
    line(mon,4,"VERSION",envelope and envelope.version or "?")
    line(mon,5,"UPTIME",uptime(meta.startedAt))
    divider(mon,6)
    line(mon,7,"FLEET",on.."/"..total.." online")
    line(mon,8,"SOURCES",count(sources))
    line(mon,9,"MONITORS",#monitors)
    line(mon,10,"SCHEMA",envelope and envelope.schema or "?")
    divider(mon,11)
    line(mon,12,"UPDATE AUTH","THIS SERVER",colors.lime)
    line(mon,13,"COMPUTER",os.getComputerID())
end

local function panelFleet(mon,envelope,meta)
    prep(mon); header(mon,"FLEET")
    local machines=meta.machines or {}; local ids={}
    for id in pairs(machines) do ids[#ids+1]=id end
    table.sort(ids,function(a,b) return (tonumber(a) or 0)<(tonumber(b) or 0) end)
    local on,total=countOnline(machines)
    line(mon,3,"ONLINE",on.."/"..total,on==total and colors.lime or colors.yellow)
    divider(mon,4)
    if #ids==0 then line(mon,6,"","No clients/nodes seen",colors.yellow); return end
    local y=5; local _,h=mon.getSize()
    for _,id in ipairs(ids) do
        if y>h then break end
        local m=machines[id]; local st=m.online~=false and "ON" or "OFF"
        line(mon,y,"",st.." #"..id.." "..tostring(m.role or "?").." "..tostring(m.version or "?"),m.online~=false and colors.lime or colors.red)
        y=y+1
        if y<=h then line(mon,y,"","  last "..age(m.lastSeen).."  "..tostring(m.updateStatus or ""),colors.lightGray); y=y+1 end
    end
end

local function panelUpdates(mon,envelope,meta)
    prep(mon); header(mon,"UPDATES")
    local up=meta.update or {}
    line(mon,3,"LOCAL",envelope and envelope.version or "?")
    line(mon,4,"REMOTE",up.remoteVersion or "?")
    line(mon,5,"RESULT",up.lastResult or "not checked",colorFor(up.lastResult))
    line(mon,6,"CHECKED",age(up.lastCheck))
    divider(mon,7)
    line(mon,8,"TARGET",up.targetVersion or "none")
    line(mon,9,"AUTHORITY",up.authority or meta.serverId or "?")
    divider(mon,10)
    line(mon,12,"","Server checks GitHub",colors.lightGray)
    line(mon,13,"","Fleet follows automatically",colors.lightGray)
end

local function panelNetwork(mon,envelope,meta)
    prep(mon); header(mon,"NETWORK")
    local machines=meta.machines or {}; local on,total=countOnline(machines)
    line(mon,3,"PROTOCOL","kimi_base_os_v1")
    line(mon,4,"SERVER",meta.serverId or "?")
    line(mon,5,"HOST","kimi-base")
    divider(mon,6)
    line(mon,7,"KNOWN",total)
    line(mon,8,"ONLINE",on,on==total and colors.lime or colors.yellow)
    line(mon,9,"SOURCES",count(meta.sources))
    line(mon,10,"STATE AGE",envelope and age(envelope.generated) or "never")
    divider(mon,11)
    line(mon,12,"","Rednet fleet coordination",colors.lightGray)
end

local function panelSources(mon,envelope,meta)
    prep(mon); header(mon,"TELEMETRY SOURCES")
    local srcs=meta.sources or {}; local ids={}
    for id in pairs(srcs) do ids[#ids+1]=id end
    table.sort(ids)
    line(mon,3,"SOURCES",#ids)
    divider(mon,4)
    if #ids==0 then line(mon,6,"","No remote telemetry yet",colors.yellow); return end
    local y=5; local _,h=mon.getSize()
    for _,id in ipairs(ids) do
        if y>h then break end
        local s=srcs[id]; local st=s.online==false and "OFF" or "ON"
        line(mon,y,"",st.." #"..id.." "..tostring(s.role or "?").." / "..count(s.state).." modules",s.online==false and colors.red or colors.lime)
        y=y+1
        if y<=h then
            local names={}; for k in pairs(s.state or {}) do names[#names+1]=k end; table.sort(names)
            line(mon,y,"","  "..table.concat(names,", "),colors.lightGray); y=y+1
        end
    end
end

local function panelHealth(mon,envelope,meta)
    prep(mon); header(mon,"HEALTH")
    local on,total=countOnline(meta.machines)
    local up=meta.update or {}
    line(mon,3,"KIMI OS","RUNNING",colors.lime)
    line(mon,4,"UPDATE AUTH","OK",colors.lime)
    line(mon,5,"NETWORK",on==total and "OK" or "DEGRADED",on==total and colors.lime or colors.yellow)
    divider(mon,6)
    line(mon,7,"FLEET",on.."/"..total)
    line(mon,8,"SOURCES",count(meta.sources))
    line(mon,9,"LAST CHECK",age(up.lastCheck))
    line(mon,10,"CHECK",up.lastResult or "not checked",colorFor(up.lastResult))
    divider(mon,11)
    line(mon,12,"SERVER ID",meta.serverId or "?")
    line(mon,13,"UPTIME",uptime(meta.startedAt))
end

local panels={panelServer,panelFleet,panelUpdates,panelNetwork,panelSources,panelHealth}

function M.init()
    monitors=getMonitors()
    term.clear(); term.setCursorPos(1,1)
    print("KIMI Command Center Admin UI")
    print("Monitors detected: "..tostring(#monitors))
end

function M.render(envelope,meta)
    monitors=getMonitors(); meta=meta or {}
    for i,entry in ipairs(monitors) do panels[((i-1)%#panels)+1](entry.mon,envelope,meta) end
end

function M.onPeripheralChange() monitors=getMonitors() end
function M.handleEvent() end
return M
