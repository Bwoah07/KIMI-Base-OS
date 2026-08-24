local Adaptive = {}

local function clamp(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function upper(v) return tostring(v or ""):upper() end

local function count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

local function gameTime()
    local ok, value = pcall(os.time, "ingame")
    local t = ok and tonumber(value) or 0
    local hour = math.floor(t % 24)
    local minute = math.floor(((t % 24) - hour) * 60)
    return string.format("%02d:%02d", hour, minute)
end

local function gameDay()
    local ok, value = pcall(os.day, "ingame")
    return ok and tostring(value) or "?"
end

local function fmtNumber(value)
    local n = tonumber(value)
    if not n then return "?" end
    local a = math.abs(n)
    if a >= 1e15 then return string.format("%.1fP", n / 1e15) end
    if a >= 1e12 then return string.format("%.1fT", n / 1e12) end
    if a >= 1e9 then return string.format("%.1fG", n / 1e9) end
    if a >= 1e6 then return string.format("%.1fM", n / 1e6) end
    if a >= 1e3 then return string.format("%.1fK", n / 1e3) end
    return tostring(math.floor(n + 0.5))
end

local function fmtFE(value, rate)
    local s = fmtNumber(value)
    return s == "?" and s or (s .. " FE" .. (rate and "/t" or ""))
end

local function niceType(value)
    local s = tostring(value or "sensor"):gsub("minecraft:", ""):gsub("_", " ")
    return upper(s)
end

local glyphs = {
    ["0"]={"111","101","101","101","111"}, ["1"]={"010","110","010","010","111"},
    ["2"]={"111","001","111","100","111"}, ["3"]={"111","001","111","001","111"},
    ["4"]={"101","101","111","001","001"}, ["5"]={"111","100","111","001","111"},
    ["6"]={"111","100","111","101","111"}, ["7"]={"111","001","010","010","010"},
    ["8"]={"111","101","111","101","111"}, ["9"]={"111","101","111","001","111"},
    [":"]={"0","1","0","1","0"}
}

function Adaptive.create(options)
    options = options or {}
    local mode = options.mode or "wall"
    local cfg = nil
    local monitors = {}
    local targets = {}
    local manualViews = {}
    local pages = {}
    local lastEnvelope, lastMeta

    local C = {
        bg = colors.black,
        panel = colors.gray,
        panel2 = colors.lightGray,
        text = colors.white,
        muted = colors.lightGray,
        good = colors.lime,
        warn = colors.orange,
        bad = colors.red,
        action = colors.blue
    }

    local function computerName()
        local label = type(os.getComputerLabel) == "function" and os.getComputerLabel() or nil
        local configured = cfg and cfg.name or nil
        if label and tostring(label):match("%S") then return tostring(label) end
        if configured and tostring(configured):match("%S") and not tostring(configured):match("^KIMI%-%d+$") then return tostring(configured) end
        return "KIMI " .. tostring(os.getComputerID())
    end

    local function detectMonitors()
        local out = {}
        for _, name in ipairs(peripheral.getNames()) do
            if peripheral.hasType(name, "monitor") then
                local mon = peripheral.wrap(name)
                if mon then
                    local scale = 1.0
                    pcall(mon.setTextScale, scale)
                    local ok, w, h = pcall(mon.getSize)
                    if ok and tonumber(w) and tonumber(h) then
                        w, h = tonumber(w), tonumber(h)
                        if w < 18 or h < 8 then
                            scale = 0.5
                            pcall(mon.setTextScale, scale)
                            local ok2, w2, h2 = pcall(mon.getSize)
                            if ok2 and tonumber(w2) and tonumber(h2) then w, h = tonumber(w2), tonumber(h2) end
                        end
                        out[#out + 1] = {
                            name = name, mon = mon, w = w, h = h, scale = scale,
                            area = w * h,
                            class = w >= 42 and "wide" or (w >= 25 and "medium" or "small")
                        }
                    end
                end
            end
        end
        table.sort(out, function(a, b)
            if a.area ~= b.area then return a.area > b.area end
            if a.w ~= b.w then return a.w > b.w end
            return a.name < b.name
        end)
        return out
    end

    local function prep(e)
        pcall(e.mon.setTextScale, e.scale)
        e.mon.setBackgroundColor(C.bg)
        e.mon.setTextColor(C.text)
        e.mon.clear()
        e.mon.setCursorPos(1, 1)
    end

    local function put(e, x, y, text, fg, bg)
        if y < 1 or y > e.h or x > e.w then return end
        x = math.max(1, x)
        text = tostring(text or "")
        e.mon.setCursorPos(x, y)
        e.mon.setTextColor(fg or C.text)
        e.mon.setBackgroundColor(bg or C.bg)
        e.mon.write(text:sub(1, math.max(0, e.w - x + 1)))
        e.mon.setBackgroundColor(C.bg)
    end

    local function fill(e, x1, y1, x2, y2, bg)
        x1, x2 = math.max(1, x1), math.min(e.w, x2)
        y1, y2 = math.max(1, y1), math.min(e.h, y2)
        if x2 < x1 or y2 < y1 then return end
        for y = y1, y2 do put(e, x1, y, string.rep(" ", x2 - x1 + 1), C.text, bg) end
    end

    local function center(e, y, text, fg, bg, x1, x2)
        x1, x2 = x1 or 1, x2 or e.w
        local width = math.max(1, x2 - x1 + 1)
        text = tostring(text or "")
        if #text > width then text = text:sub(1, width) end
        put(e, x1 + math.max(0, math.floor((width - #text) / 2)), y, text, fg, bg)
    end

    local function header(e, title, right)
        fill(e, 1, 1, e.w, 2, C.panel)
        put(e, 2, 1, upper(title), C.text, C.panel)
        put(e, 2, 2, upper(computerName()), C.muted, C.panel)
        if right then put(e, math.max(2, e.w - #tostring(right)), 1, tostring(right), C.text, C.panel) end
    end

    local function line(e, y, label, value, color, x)
        x = x or 2
        label = label and upper(label) or ""
        local prefix = label ~= "" and (label .. "  ") or ""
        put(e, x, y, prefix, C.muted)
        put(e, x + #prefix, y, value, color or C.text)
    end

    local function rule(e, y, x1, x2)
        x1, x2 = x1 or 2, x2 or e.w - 1
        if x2 >= x1 then put(e, x1, y, string.rep("-", x2 - x1 + 1), C.panel) end
    end

    local function register(e, target)
        targets[e.name] = targets[e.name] or {}
        targets[e.name][#targets[e.name] + 1] = target
    end

    local function button(e, name, x1, y1, x2, y2, text, enabled, data, bg, fg)
        enabled = enabled ~= false
        bg = enabled and (bg or C.action) or C.panel
        fg = enabled and (fg or C.text) or C.muted
        fill(e, x1, y1, x2, y2, bg)
        center(e, math.floor((y1 + y2) / 2), text, fg, bg, x1, x2)
        register(e, { name=name, x1=x1, y1=y1, x2=x2, y2=y2, enabled=enabled, data=data, label=text })
    end

    local function stateOf(envelope) return envelope and envelope.state or {} end

    local function sourceName(source, envelope)
        source = tostring(source or "server")
        if source == "server" then return "MAIN SERVER" end
        local s = stateOf(envelope)
        local item = (s.sources and s.sources[source]) or (s.fleet and (s.fleet[source] or s.fleet[tonumber(source)]))
        if item and item.name and tostring(item.name):match("%S") then return tostring(item.name) end
        return "COMPUTER " .. source
    end

    local function localSource(meta)
        return meta and meta.localServer and "server" or tostring(os.getComputerID())
    end

    local function localDoors(envelope, meta)
        local wanted, out = localSource(meta), {}
        for _, door in ipairs(stateOf(envelope).doors and stateOf(envelope).doors.doors or {}) do
            if tostring(door._source or door.source or "server") == wanted then out[#out + 1] = door end
        end
        return out
    end

    local function globalSensors(envelope)
        local s, out = stateOf(envelope), {}
        for _, sensor in ipairs(s.attachments and s.attachments.sensors or {}) do out[#out + 1] = sensor end
        if #out == 0 and s.environment and s.environment._status ~= "offline" then
            local env = s.environment
            out[1] = {
                name = env.sensor or "Environment",
                type = "environment_detector",
                summary = tostring(env.weather or "") .. " " .. tostring(env.biome or ""),
                metrics = { biome=env.biome, dimension=env.dimension, blockLight=env.blockLight, skyLight=env.skyLight },
                _source = env._source or "server"
            }
        end
        return out
    end

    local function localSensors(meta)
        local s = meta and meta.localState or {}
        return s.attachments and s.attachments.sensors or {}
    end

    local function choosePower(raw)
        raw = raw or {}
        local best = nil
        local function consider(p)
            if type(p) ~= "table" then return end
            local cap = tonumber(p.capacity) or 0
            local stored = tonumber(p.stored) or 0
            local score = (cap > 0 and 1000000 or 0) + (stored > 0 and 10000 or 0) + (tonumber(p.input) or 0) + (tonumber(p.output) or 0)
            if not best or score > best.score then best = { score=score, value=p } end
        end
        for _, p in ipairs(raw.matrices or {}) do consider(p) end
        for _, p in ipairs(raw.fluxNetworks or {}) do consider(p) end
        for _, p in ipairs(raw.energyDetectors or {}) do consider(p) end
        consider(raw)
        return best and best.value or raw
    end

    local function powerState(envelope, meta, localOnly)
        local raw
        if localOnly and meta and meta.localState and meta.localState.power then raw = meta.localState.power else raw = stateOf(envelope).power end
        raw = raw or {}
        return raw, choosePower(raw)
    end

    local function percent(p)
        local n = tonumber(p and p.filledPercentage)
        if n then if n <= 1 then n = n * 100 end; return clamp(n, 0, 100) end
        local stored, cap = tonumber(p and p.stored), tonumber(p and p.capacity)
        if stored and cap and cap > 0 then return clamp(stored / cap * 100, 0, 100) end
        return nil
    end

    local function metric(sensor)
        local m = sensor and sensor.metrics or {}
        local order = {"temperature","humidity","radiation","onlinePlayers","biome","dimension","blockLight","skyLight","transferRate","storedEnergy","energy","fuel"}
        for _, key in ipairs(order) do
            if m[key] ~= nil then return niceType(key) .. "  " .. tostring(m[key]) end
        end
        return upper(sensor and sensor.summary or "TELEMETRY ONLINE")
    end

    local function contextLine(envelope)
        local s = stateOf(envelope)
        local env = s.environment
        if env and env._status ~= "offline" then
            local weather = upper(env.weather or "CLEAR")
            local biome = tostring(env.biome or ""):gsub("minecraft:", "")
            if biome ~= "" and biome ~= "UNKNOWN" then weather = weather .. "  " .. upper(biome) end
            return weather, (env.weather == "THUNDER" and C.bad or (env.weather == "RAINING" and C.warn or C.good))
        end
        local sensors = globalSensors(envelope)
        if #sensors > 0 then return tostring(#sensors) .. " SENSOR" .. (#sensors == 1 and "" or "S") .. " ONLINE  " .. metric(sensors[1]), C.good end
        return "NO ENVIRONMENT SENSOR", C.warn
    end

    local function drawClock(e, y)
        local value = gameTime()
        if e.h < 12 then center(e, y, value, C.text); return 1 end
        local xScale = e.w >= 38 and 2 or 1
        local charGap = 1
        local widths, total = {}, 0
        for i=1,#value do
            local ch = value:sub(i,i)
            widths[i] = (ch == ":" and 1 or 3) * xScale
            total = total + widths[i] + (i < #value and charGap or 0)
        end
        local x = math.max(2, math.floor((e.w - total) / 2) + 1)
        for i=1,#value do
            local ch = value:sub(i,i)
            local rows = glyphs[ch]
            local cols = ch == ":" and 1 or 3
            for r=1,5 do
                for c=1,cols do
                    if rows[r]:sub(c,c) == "1" then fill(e, x + (c-1)*xScale, y+r-1, x + c*xScale - 1, y+r-1, C.text) end
                end
            end
            x = x + widths[i] + charGap
        end
        return 5
    end

    local function card(e, x1, y1, x2, y2, title, value, valueColor, sub)
        fill(e, x1, y1, x2, y2, C.panel)
        put(e, x1+1, y1, upper(title), C.muted, C.panel)
        center(e, math.min(y2, y1+2), value, valueColor or C.text, C.panel, x1, x2)
        if sub and y2 >= y1+3 then center(e, y2, sub, C.muted, C.panel, x1, x2) end
    end

    local function nav(e)
        if mode ~= "admin" or e.w < 30 or e.h < 14 then return 0 end
        local items = {{"nav_auto","AUTO"},{"nav_overview","HOME"},{"nav_doors","DOORS"},{"nav_power","POWER"},{"nav_sensors","SENS"}}
        local cell = math.floor(e.w / #items)
        for i,item in ipairs(items) do
            local x1 = (i-1)*cell+1
            local x2 = i == #items and e.w or i*cell
            button(e,item[1],x1,e.h-1,x2,e.h,item[2],true,nil,C.panel,C.text)
        end
        return 2
    end

    local function renderStatus(e, envelope, meta)
        prep(e); header(e, "BASE STATUS", "DAY " .. gameDay())
        local clockH = drawClock(e, 4)
        local y = 4 + clockH + 1
        local context, color = contextLine(envelope)
        center(e, y, context, color)
        local s = stateOf(envelope)
        local online,total = 0,0
        for _,m in pairs(s.fleet or {}) do total=total+1; if m.online ~= false then online=online+1 end end
        center(e, y+2, tostring(#globalSensors(envelope)) .. " SENSORS   " .. tostring(online) .. "/" .. tostring(total) .. " COMPUTERS", C.muted)
        if meta and meta.connected == false then center(e, math.min(e.h-1,y+4), "SEARCHING FOR KIMI SERVER", C.warn) end
    end

    local function renderOverview(e, envelope)
        prep(e); header(e, "COMMAND CENTER", gameTime())
        local s = stateOf(envelope)
        local doors = s.doors and s.doors.doors or {}
        local open,offline = 0,0
        for _,d in ipairs(doors) do if d.online == false then offline=offline+1 elseif d.open then open=open+1 end end
        local sensors = globalSensors(envelope)
        local raw, main = powerState(envelope, nil, false)
        local p = percent(main)
        local online,total = 0,0
        for _,m in pairs(s.fleet or {}) do total=total+1; if m.online ~= false then online=online+1 end end
        local bottom = e.h - nav(e) - 1
        local top = 4
        local mid = math.floor(e.w/2)
        local h = math.max(4, math.floor((bottom-top-1)/2))
        card(e,2,top,mid-1,top+h,"Doors",tostring(open).." OPEN / "..tostring(#doors),offline>0 and C.warn or C.good,offline>0 and tostring(offline).." OFFLINE" or "ALL REACHABLE")
        card(e,mid+1,top,e.w-1,top+h,"Power",p and string.format("%.1f%%",p) or "ONLINE",p and (p<25 and C.warn or C.good) or C.good,tostring(raw.onlineSources or 0).." SOURCES")
        local y2=top+h+2
        card(e,2,y2,mid-1,bottom,"Sensors",tostring(#sensors).." LIVE",#sensors>0 and C.good or C.warn,#sensors>0 and metric(sensors[1]) or "NO DATA")
        card(e,mid+1,y2,e.w-1,bottom,"Fleet",tostring(online).."/"..tostring(total).." ONLINE",online==total and C.good or C.warn,"AUTO SYNC")
    end

    local function displayDoorName(door, envelope)
        local name = tostring(door.name or "")
        if name == "" or name:match("^DOOR%s+%d+") then
            local src = sourceName(door._source or door.source, envelope)
            if not src:match("^COMPUTER%s+%d+$") and src ~= "MAIN SERVER" then return upper(src) end
            if door.side then return upper(tostring(door.side) .. " DOOR") end
        end
        return upper(name ~= "" and name or ("DOOR " .. tostring(door.id or "?")))
    end

    local function renderDoors(e, envelope, meta, localOnly, readonly)
        prep(e); header(e, localOnly and "LOCAL DOORS" or "DOOR CONTROL", gameTime())
        local doors = localOnly and localDoors(envelope,meta) or (stateOf(envelope).doors and stateOf(envelope).doors.doors or {})
        local context,color = contextLine(envelope)
        center(e,4,context,color)
        if #doors == 0 then
            center(e,math.max(7,math.floor(e.h/2)),localOnly and "NO LOCAL DOOR CONFIGURED" or "NO DOORS CONFIGURED",C.warn)
            if mode=="admin" and not readonly then button(e,"door_setup",2,e.h-4,e.w-1,e.h-2,"SET UP A DOOR",true,nil,C.action) end
            nav(e)
            return
        end
        local navRows = mode=="admin" and 2 or 0
        local top,bottom = 6,e.h-navRows-1
        local cols = e.w>=42 and 2 or 1
        if #doors >= 3 and e.w>=58 then cols=3 end
        local rows = math.ceil(#doors/cols)
        local gap=1
        local cellW=math.floor((e.w-2-(cols-1)*gap)/cols)
        local cellH=math.max(4,math.floor((bottom-top+1-(rows-1)*gap)/rows))
        for i,door in ipairs(doors) do
            local col=(i-1)%cols; local row=math.floor((i-1)/cols)
            local x1=2+col*(cellW+gap); local x2=math.min(e.w-1,x1+cellW-1)
            local y1=top+row*(cellH+gap); local y2=math.min(bottom,y1+cellH-1)
            if y1<=bottom then
                local bg=door.online==false and C.panel or (door.open and C.good or C.action)
                local fg=door.open and colors.black or C.text
                fill(e,x1,y1,x2,y2,bg)
                center(e,y1+1,displayDoorName(door,envelope),fg,bg,x1,x2)
                center(e,math.min(y2,y1+2),door.online==false and "OFFLINE" or (door.open and "OPEN" or "CLOSED"),fg,bg,x1,x2)
                if not readonly then
                    register(e,{name=localOnly and "door_toggle_local" or "door_toggle",x1=x1,y1=y1,x2=x2,y2=y2,enabled=door.online~=false,label="DOOR",data={_source=door._source or door.source,target=door.target,side=door.side,id=door.id}})
                end
            end
        end
        if mode=="admin" and not readonly then button(e,"door_setup",2,bottom,math.min(e.w-1,18),bottom,"SETUP",true,nil,C.panel) end
        nav(e)
    end

    local function renderDoorSetup(e,envelope)
        prep(e); header(e,"DOOR SETUP","CHOOSE OUTPUT")
        local candidates={}
        for _,c in ipairs(stateOf(envelope).doors and stateOf(envelope).doors.candidates or {}) do if not c.configured then candidates[#candidates+1]=c end end
        line(e,4,"AVAILABLE",tostring(#candidates).." OUTPUTS",#candidates>0 and C.good or C.warn)
        center(e,5,"ONLY ADD THE OUTPUT THAT PHYSICALLY DRIVES THE DOOR",C.muted)
        local pageSize=math.max(1,math.floor((e.h-10)/3)); local maxPage=math.max(1,math.ceil(#candidates/pageSize))
        local key=e.name..":door_setup"; pages[key]=clamp(pages[key] or 1,1,maxPage); local page=pages[key]
        local y=7; local first=(page-1)*pageSize+1
        for i=first,math.min(#candidates,first+pageSize-1) do
            local c=candidates[i]; local src=sourceName(c._source,envelope)
            local target=c.target=="computer" and tostring(c.label or c.side or "OUTPUT") or tostring(c.target or "PERIPHERAL")
            button(e,"door_register",2,y,e.w-1,y+1,upper(src.." / "..target),true,{key=c.key},C.action); y=y+3
        end
        local third=math.floor(e.w/3); button(e,"nav_doors",1,e.h-1,third,e.h,"BACK",true,nil,C.panel)
        button(e,"page_prev",third+1,e.h-1,third*2,e.h,"PREV",page>1,{key=key},C.panel)
        button(e,"page_next",third*2+1,e.h-1,e.w,e.h,"NEXT",page<maxPage,{key=key},C.panel)
    end

    local function renderSensors(e,envelope,meta,localOnly)
        prep(e); header(e,localOnly and "LOCAL SENSORS" or "SENSORS",gameTime())
        local list=localOnly and localSensors(meta) or globalSensors(envelope)
        line(e,4,"LIVE",tostring(#list).." SENSOR"..(#list==1 and "" or "S"),#list>0 and C.good or C.warn)
        if #list==0 then center(e,8,"NO SENSOR DATA RECEIVED",C.warn); center(e,10,"CHECK NODE / MODEM / PERIPHERAL",C.muted); return end
        local cols=e.w>=46 and 2 or 1
        local usable=e.h-6; local rowsPerCol=math.max(1,math.floor(usable/4)); local perPage=rowsPerCol*cols
        local maxPage=math.max(1,math.ceil(#list/perPage)); local key=e.name..":sensors:"..tostring(localOnly)
        pages[key]=clamp(pages[key] or 1,1,maxPage); local page=pages[key]; local first=(page-1)*perPage+1
        for slot=0,perPage-1 do
            local idx=first+slot; local sensor=list[idx]; if not sensor then break end
            local col=slot%cols; local row=math.floor(slot/cols)
            local x1=2+col*math.floor(e.w/cols); local x2=col==cols-1 and e.w-1 or math.floor(e.w/cols)
            local y=6+row*4
            put(e,x1,y,upper(sensor.name or sensor.type or ("SENSOR "..idx)),C.text)
            put(e,x1,y+1,metric(sensor),C.good)
            put(e,x1,y+2,upper((localOnly and "LOCAL" or sourceName(sensor._source,envelope)).." / "..niceType(sensor.type)),C.muted)
            if x2>x1 then rule(e,y+3,x1,x2) end
        end
        if maxPage>1 then center(e,e.h,tostring(page).."/"..tostring(maxPage).."  TOUCH EDGES TO PAGE",C.muted) end
    end

    local function renderPower(e,envelope,meta,localOnly)
        prep(e); header(e,localOnly and "LOCAL POWER" or "POWER",gameTime())
        local raw,main=powerState(envelope,meta,localOnly)
        local sources=tonumber(raw.onlineSources) or 0
        if sources<=0 then center(e,8,"NO POWER TELEMETRY",C.warn); return end
        local p=percent(main); local color=not p and C.good or (p>=60 and C.good or (p>=25 and C.warn or C.bad))
        if e.class=="wide" and e.h>=15 then
            local split=math.floor(e.w*0.52)
            local value=p and string.format("%.1f%%",p) or "ONLINE"
            card(e,2,4,split-1,9,"ENERGY",value,color,fmtFE(main.stored,false).." / "..fmtFE(main.capacity,false))
            line(e,11,"INPUT",fmtFE(main.input,true),C.good,3)
            line(e,12,"OUTPUT",fmtFE(main.output,true),C.warn,3)
            local barY=14; local x1=3; local x2=split-2
            if p and x2>x1 then
                local filled=math.floor((x2-x1+1)*p/100)
                if filled>0 then fill(e,x1,barY,x1+filled-1,barY,color) end
                if x1+filled<=x2 then fill(e,x1+filled,barY,x2,barY,C.panel) end
            end
            put(e,split+1,4,"POWER SOURCES",C.muted)
            local y=6
            for i,m in ipairs(raw.matrices or {}) do if y>e.h-1 then break end; line(e,y,"MATRIX "..i,(percent(m) and string.format("%.1f%%",percent(m)) or "ONLINE").."  "..fmtFE(m.stored,false),C.good,split+1); y=y+2 end
            for i,f in ipairs(raw.fluxNetworks or {}) do if y>e.h-1 then break end; line(e,y,"FLUX "..i,tostring(f.networkName or f.peripheral or "NETWORK"),f.healthy==false and C.warn or C.good,split+1); if y+1<=e.h-1 then put(e,split+3,y+1,fmtFE(f.stored,false).."  +"..fmtFE(f.input,true).."  -"..fmtFE(f.output,true),C.muted) end; y=y+3 end
            if y<=e.h-1 then line(e,y,"TOTAL",tostring(sources).." SOURCES",C.muted,split+1) end
        else
            center(e,5,p and string.format("%.1f%%",p) or "POWER ONLINE",color)
            if p then
                local x1,x2=3,e.w-2; local filled=math.floor((x2-x1+1)*p/100)
                if filled>0 then fill(e,x1,7,x1+filled-1,8,color) end
                if x1+filled<=x2 then fill(e,x1+filled,7,x2,8,C.panel) end
            end
            line(e,10,"STORED",fmtFE(main.stored,false)); line(e,11,"CAPACITY",fmtFE(main.capacity,false))
            line(e,13,"INPUT",fmtFE(main.input,true),C.good); line(e,14,"OUTPUT",fmtFE(main.output,true),C.warn)
            if e.h>=17 then line(e,16,"SOURCES",tostring(sources).."  MATRIX "..tostring(raw.matrixCount or 0).."  FLUX "..tostring(raw.fluxCount or 0),C.muted) end
        end
    end

    local function renderFleet(e,envelope)
        prep(e); header(e,"KIMI FLEET",gameTime())
        local fleet=stateOf(envelope).fleet or {}; local ids={}; for id in pairs(fleet) do ids[#ids+1]=id end
        table.sort(ids,function(a,b) return tostring(a)<tostring(b) end)
        local online=0; for _,id in ipairs(ids) do if fleet[id].online~=false then online=online+1 end end
        line(e,4,"ONLINE",tostring(online).."/"..tostring(#ids),online==#ids and C.good or C.warn); rule(e,5)
        local y=7
        for _,id in ipairs(ids) do if y>e.h-1 then break end; local m=fleet[id]
            put(e,2,y,upper(m.name or ("COMPUTER "..tostring(id))),m.online==false and C.bad or C.good)
            put(e,2,y+1,upper(tostring(m.role or "?").." / "..tostring(m.version or "?").." / ID "..tostring(id)),C.muted); y=y+3
        end
    end

    local function capabilities(envelope,meta)
        local s=stateOf(envelope); local lp=meta and meta.localState and meta.localState.power or {}
        return {
            localDoors=localDoors(envelope,meta), localSensors=localSensors(meta), sensors=globalSensors(envelope),
            doors=s.doors and s.doors.doors or {}, hasPower=(tonumber(s.power and s.power.onlineSources) or 0)>0,
            hasLocalPower=(tonumber(lp.onlineSources) or 0)>0
        }
    end

    local function autoViews(envelope,meta)
        local c=capabilities(envelope,meta); local v={}
        if mode=="admin" then
            v[#v+1]="overview"
            if #c.doors>0 then v[#v+1]="doors" end
            if c.hasPower then v[#v+1]="power" end
            if #c.sensors>0 then v[#v+1]="sensors" end
            v[#v+1]="fleet"; v[#v+1]="status"
        else
            if #c.localDoors>0 then v[#v+1]="local_doors" end
            if c.hasLocalPower then v[#v+1]="power_local" end
            if #c.localSensors>0 then v[#v+1]="sensors_local" end
            v[#v+1]="status"
            if c.hasPower then v[#v+1]="power" end
            if #c.sensors>0 then v[#v+1]="sensors" end
            if #c.doors>0 then v[#v+1]="doors_readonly" end
        end
        return v
    end

    local function plan(envelope,meta)
        local available=autoViews(envelope,meta); if #available==0 then available={"status"} end
        local out={}
        for i,e in ipairs(monitors) do
            local view=manualViews[e.name] or available[((i-1)%#available)+1]
            if e.class=="small" and (view=="overview" or view=="fleet") then view="status" end
            out[e.name]=view
        end
        return out
    end

    local renderers={
        status=renderStatus, overview=renderOverview,
        doors=function(e,env,meta) renderDoors(e,env,meta,false,false) end,
        local_doors=function(e,env,meta) renderDoors(e,env,meta,true,false) end,
        doors_readonly=function(e,env,meta) renderDoors(e,env,meta,false,true) end,
        door_setup=renderDoorSetup,
        sensors=function(e,env,meta) renderSensors(e,env,meta,false) end,
        sensors_local=function(e,env,meta) renderSensors(e,env,meta,true) end,
        power=function(e,env,meta) renderPower(e,env,meta,false) end,
        power_local=function(e,env,meta) renderPower(e,env,meta,true) end,
        fleet=renderFleet
    }

    local function renderOne(e,view,envelope,meta)
        targets[e.name]={}
        ;(renderers[view] or renderStatus)(e,envelope,meta or {})
    end

    local function redraw(name)
        if not lastEnvelope then return end
        local assigned=plan(lastEnvelope,lastMeta or {})
        for _,e in ipairs(monitors) do if e.name==name then renderOne(e,manualViews[name] or assigned[name] or "status",lastEnvelope,lastMeta or {}); return end end
    end

    local M={}
    function M.init(newCfg)
        cfg=newCfg or cfg or {}
        monitors=detectMonitors()
        term.clear(); term.setCursorPos(1,1)
        print("KIMI Adaptive Display v2")
        print("Profile: "..tostring(mode).." / monitors: "..tostring(#monitors))
        for i,e in ipairs(monitors) do print(string.format("  %d) %s %dx%d scale %.1f",i,e.name,e.w,e.h,e.scale)) end
    end

    function M.render(envelope,meta)
        monitors=detectMonitors(); lastEnvelope,lastMeta=envelope,meta or {}; targets={}
        local assigned=plan(envelope,lastMeta)
        for _,e in ipairs(monitors) do renderOne(e,assigned[e.name] or "status",envelope,lastMeta) end
    end

    function M.onPeripheralChange() monitors=detectMonitors(); targets={} end

    function M.handleEvent(event,envelope,action)
        if type(event)~="table" or event[1]~="monitor_touch" then return end
        local name,x,y=event[2],tonumber(event[3]),tonumber(event[4]); if not x or not y then return end
        for _,t in ipairs(targets[name] or {}) do
            if t.enabled and x>=t.x1 and x<=t.x2 and y>=t.y1 and y<=t.y2 then
                local entry; for _,e in ipairs(monitors) do if e.name==name then entry=e; break end end
                if entry then fill(entry,t.x1,t.y1,t.x2,t.y2,colors.white); center(entry,math.floor((t.y1+t.y2)/2),t.label or "OK",colors.black,colors.white,t.x1,t.x2) end
                local n=t.name
                if n=="nav_auto" then manualViews[name]=nil
                elseif n=="nav_overview" then manualViews[name]="overview"
                elseif n=="nav_doors" then manualViews[name]="doors"
                elseif n=="nav_power" then manualViews[name]="power"
                elseif n=="nav_sensors" then manualViews[name]="sensors"
                elseif n=="door_setup" then manualViews[name]="door_setup"
                elseif n=="page_prev" and t.data then pages[t.data.key]=math.max(1,(pages[t.data.key] or 1)-1)
                elseif n=="page_next" and t.data then pages[t.data.key]=(pages[t.data.key] or 1)+1
                elseif n=="door_register" and t.data then if action then action("doors","register",t.data) end; manualViews[name]="doors"
                elseif n=="door_toggle" and t.data then if action then action("doors","toggle",t.data) end
                elseif n=="door_toggle_local" and t.data then if action then action("__local_doors","toggle",t.data) end
                end
                redraw(name); return true
            end
        end
        local view=manualViews[name]
        if view=="sensors" or view=="sensors_local" then
            local key=name..":sensors:"..tostring(view=="sensors_local")
            if x<=3 then pages[key]=math.max(1,(pages[key] or 1)-1); redraw(name); return true end
            local entry; for _,e in ipairs(monitors) do if e.name==name then entry=e; break end end
            if entry and x>=entry.w-2 then pages[key]=(pages[key] or 1)+1; redraw(name); return true end
        end
    end
    return M
end

return Adaptive
