local Adaptive = {}

local function clamp(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function upper(v) return tostring(v or ""):upper() end

local function nice(v)
    local s = tostring(v or ""):gsub("minecraft:", ""):gsub("[_%-]", " ")
    s = s:gsub("(%l)(%u)", "%1 %2")
    return upper(s)
end

local function gameTime()
    local ok, value = pcall(os.time, "ingame")
    local t = ok and tonumber(value) or 0
    local h = math.floor(t % 24)
    local m = math.floor(((t % 24) - h) * 60)
    return string.format("%02d:%02d", h, m)
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
    if math.abs(n - math.floor(n)) > 0.01 then return string.format("%.2f", n) end
    return tostring(math.floor(n))
end

local function fmtFE(value, rate)
    local s = fmtNumber(value)
    if s == "?" then return s end
    return s .. " FE" .. (rate and "/t" or "")
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
    local cfg, monitors, lastEnvelope, lastMeta
    local targets, manualViews, pages = {}, {}, {}

    local C = {
        bg=colors.black, panel=colors.gray, dim=colors.lightGray, text=colors.white,
        good=colors.lime, warn=colors.orange, bad=colors.red, action=colors.blue,
        accent=colors.cyan or colors.lightBlue
    }

    local function roleName() return mode == "admin" and "MAIN BASE" or "ROOM PANEL" end

    local function computerName()
        local label = type(os.getComputerLabel) == "function" and os.getComputerLabel() or nil
        if label and tostring(label):match("%S") and not tostring(label):match("^KIMI[%s%-]?%d+$") then return upper(label) end
        local configured = cfg and cfg.name or nil
        if configured and tostring(configured):match("%S") and not tostring(configured):match("^KIMI[%s%-]?%d+$") then return upper(configured) end
        return roleName()
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
                            if ok2 then w,h=tonumber(w2) or w,tonumber(h2) or h end
                        end
                        out[#out+1] = { name=name, mon=mon, w=w, h=h, scale=scale, area=w*h, class=w>=45 and "wide" or (w>=25 and "medium" or "small") }
                    end
                end
            end
        end
        table.sort(out, function(a,b)
            if a.area ~= b.area then return a.area > b.area end
            if a.w ~= b.w then return a.w > b.w end
            return a.name < b.name
        end)
        return out
    end

    local function prep(e)
        pcall(e.mon.setTextScale, e.scale)
        e.mon.setBackgroundColor(C.bg); e.mon.setTextColor(C.text); e.mon.clear(); e.mon.setCursorPos(1,1)
    end

    local function put(e,x,y,text,fg,bg)
        if y < 1 or y > e.h or x > e.w then return end
        x=math.max(1,x); text=tostring(text or "")
        e.mon.setCursorPos(x,y); e.mon.setTextColor(fg or C.text); e.mon.setBackgroundColor(bg or C.bg)
        e.mon.write(text:sub(1,math.max(0,e.w-x+1))); e.mon.setBackgroundColor(C.bg)
    end

    local function fill(e,x1,y1,x2,y2,bg)
        x1,x2=math.max(1,x1),math.min(e.w,x2); y1,y2=math.max(1,y1),math.min(e.h,y2)
        if x2<x1 or y2<y1 then return end
        for y=y1,y2 do put(e,x1,y,string.rep(" ",x2-x1+1),C.text,bg) end
    end

    local function center(e,y,text,fg,bg,x1,x2)
        x1,x2=x1 or 1,x2 or e.w
        local width=math.max(1,x2-x1+1); text=tostring(text or "")
        if #text>width then text=text:sub(1,width) end
        put(e,x1+math.max(0,math.floor((width-#text)/2)),y,text,fg,bg)
    end

    local function rule(e,y,x1,x2,color)
        x1,x2=x1 or 2,x2 or e.w-1
        if x2>=x1 then put(e,x1,y,string.rep("-",x2-x1+1),color or C.panel) end
    end

    local function line(e,y,label,value,color,x)
        x=x or 2
        local prefix=label and (upper(label).."  ") or ""
        put(e,x,y,prefix,C.dim); put(e,x+#prefix,y,tostring(value or ""),color or C.text)
    end

    local function header(e,title,right)
        put(e,2,1,upper(title),C.text)
        if right then put(e,math.max(2,e.w-#tostring(right)-1),1,tostring(right),C.dim) end
        put(e,2,2,computerName(),C.dim)
        rule(e,3,1,e.w,C.panel)
    end

    local function register(e,t)
        targets[e.name]=targets[e.name] or {}
        targets[e.name][#targets[e.name]+1]=t
    end

    local function button(e,name,x1,y1,x2,y2,text,enabled,data,bg,fg)
        enabled=enabled~=false; bg=enabled and (bg or C.action) or C.panel; fg=enabled and (fg or C.text) or C.dim
        x1,x2=math.max(2,x1),math.min(e.w-1,x2); y1,y2=math.max(1,y1),math.min(e.h,y2)
        if x2<x1 or y2<y1 then return end
        fill(e,x1,y1,x2,y2,bg)
        local tx1,tx2=x1+2,x2-2
        if tx2<tx1 then tx1,tx2=x1+1,x2-1 end
        center(e,math.floor((y1+y2)/2),text,fg,bg,tx1,tx2)
        register(e,{name=name,x1=x1,y1=y1,x2=x2,y2=y2,enabled=enabled,data=data,label=text})
    end

    local function stateOf(env) return env and env.state or {} end
    local function localSource(meta) return meta and meta.localServer and "server" or tostring(os.getComputerID()) end

    local function sourceName(source, env)
        source=tostring(source or "server")
        if source=="server" then return "MAIN BASE" end
        local s=stateOf(env)
        local item=(s.sources and s.sources[source]) or (s.fleet and (s.fleet[source] or s.fleet[tonumber(source)]))
        if item and item.name and tostring(item.name):match("%S") and not tostring(item.name):match("^KIMI[%s%-]?%d+$") then return upper(item.name) end
        if item and item.role=="node" then return "REMOTE NODE" end
        return "ROOM PANEL"
    end

    local function localDoors(env,meta)
        local out,seen={},{}
        local localState=meta and meta.localState or {}
        for _,d in ipairs(localState.doors and localState.doors.localDoors or {}) do
            local key=tostring(d.key or (tostring(d.target).."|"..tostring(d.side or "")))
            local item={}; for k,v in pairs(d) do item[k]=v end
            item._source=localSource(meta); item.source=item._source; item.online=d.online~=false
            out[#out+1]=item; seen[key]=true
        end
        for _,d in ipairs(stateOf(env).doors and stateOf(env).doors.doors or {}) do
            if tostring(d._source or d.source or "server")==localSource(meta) then
                local key=tostring(d.key or (tostring(d.target).."|"..tostring(d.side or "")))
                if not seen[key] then out[#out+1]=d; seen[key]=true end
            end
        end
        return out
    end

    local function localCandidates(meta)
        local s=meta and meta.localState or {}; local out={}
        for _,c in ipairs(s.doors and s.doors.candidates or {}) do if c.localConfigured~=true then out[#out+1]=c end end
        return out
    end

    local function localSensors(meta)
        local s=meta and meta.localState or {}
        return s.attachments and s.attachments.sensors or {}
    end

    local function localDevices(meta)
        local s=meta and meta.localState or {}
        return s.attachments and s.attachments.devices or {}
    end

    local function globalSensors(env)
        local out={}
        for _,sensor in ipairs(stateOf(env).attachments and stateOf(env).attachments.sensors or {}) do out[#out+1]=sensor end
        local s=stateOf(env)
        if #out==0 and s.environment and s.environment._status~="offline" then
            local v=s.environment
            out[1]={name="Environment",type="environment_detector",metrics={weather=v.weather,biome=v.biome,dimension=v.dimension,blockLight=v.blockLight,skyLight=v.skyLight,radiation=v.radiation},_source=v._source or "server"}
        end
        return out
    end

    local function choosePower(raw)
        raw=raw or {}; local best,bestScore=nil,-1
        local function consider(p)
            if type(p)~="table" then return end
            local cap=tonumber(p.capacity) or 0; local stored=tonumber(p.stored) or 0; local input=tonumber(p.input) or 0; local output=tonumber(p.output) or 0
            local score=(cap>0 and 1000000000 or 0)+(stored>0 and 10000000 or 0)+math.abs(input)+math.abs(output)
            if score>bestScore then best,bestScore=p,score end
        end
        for _,p in ipairs(raw.matrices or {}) do consider(p) end
        for _,p in ipairs(raw.fluxNetworks or {}) do consider(p) end
        for _,p in ipairs(raw.energyDetectors or {}) do consider(p) end
        consider(raw)
        return best or raw
    end

    local function powerState(env,meta,localOnly)
        local raw=localOnly and meta and meta.localState and meta.localState.power or stateOf(env).power
        raw=raw or {}; return raw,choosePower(raw)
    end

    local function percent(p)
        local n=tonumber(p and p.filledPercentage)
        if n then if n<=1 then n=n*100 end; return clamp(n,0,100) end
        local stored,cap=tonumber(p and p.stored),tonumber(p and p.capacity)
        if stored and cap and cap>0 then return clamp(stored/cap*100,0,100) end
        return nil
    end

    local function sensorTitle(sensor)
        local t=nice(sensor and sensor.type or "sensor")
        if t:find("ENVIRONMENT",1,true) then return "ENVIRONMENT" end
        if t:find("PLAYER",1,true) then return "PLAYERS" end
        if t:find("GEO",1,true) then return "GEO SCANNER" end
        if t:find("BLOCK",1,true) then return "BLOCK READER" end
        return t~="" and t or "SENSOR"
    end

    local function sensorMetrics(sensor)
        local m=sensor and sensor.metrics or {}; local out={}
        local order={{"temperature","TEMP"},{"humidity","HUMIDITY"},{"radiationRaw","RADIATION"},{"radiation","RADIATION"},{"onlinePlayers","PLAYERS"},{"biome","BIOME"},{"dimension","DIMENSION"},{"blockLight","BLOCK LIGHT"},{"skyLight","SKY LIGHT"},{"pressure","PRESSURE"},{"entityCount","ENTITIES"},{"playerCount","PLAYERS"},{"maxScanRadius","SCAN RANGE"}}
        for _,pair in ipairs(order) do if m[pair[1]]~=nil then out[#out+1]={pair[2],tostring(m[pair[1]])} end end
        return out
    end

    local function context(env)
        local s=stateOf(env); local v=s.environment
        if v and v._status~="offline" then
            local weather=upper(v.weather or "CLEAR"); local biome=tostring(v.biome or ""):gsub("minecraft:","")
            if biome~="" and biome~="UNKNOWN" then weather=weather.."  "..upper(biome) end
            return weather,(v.weather=="THUNDER" and C.bad or (v.weather=="RAINING" and C.warn or C.good))
        end
        local sensors=globalSensors(env)
        if #sensors>0 then return tostring(#sensors).." SENSOR"..(#sensors==1 and "" or "S").." ONLINE",C.good end
        return "NO ENVIRONMENT SENSOR",C.warn
    end

    local function roomContext(env,meta)
        local sensors=localSensors(meta)
        if #sensors>0 then return tostring(#sensors).." LOCAL SENSOR"..(#sensors==1 and "" or "S").." ONLINE",C.good end
        return context(env)
    end

    local function drawClock(e,y,x1,x2)
        local value=gameTime(); x1,x2=x1 or 1,x2 or e.w
        if e.h<12 or x2-x1<22 then center(e,y,value,C.text,nil,x1,x2); return end
        local xScale=(x2-x1+1)>=38 and 2 or 1; local gap=1; local widths,total={},0
        for i=1,#value do local ch=value:sub(i,i); widths[i]=(ch==":" and 1 or 3)*xScale; total=total+widths[i]+(i<#value and gap or 0) end
        local x=x1+math.max(0,math.floor(((x2-x1+1)-total)/2))
        for i=1,#value do
            local ch=value:sub(i,i); local rows=glyphs[ch]; local cols=ch==":" and 1 or 3
            for r=1,5 do for c=1,cols do if rows[r]:sub(c,c)=="1" then fill(e,x+(c-1)*xScale,y+r-1,x+c*xScale-1,y+r-1,C.text) end end end
            x=x+widths[i]+gap
        end
    end

    local function drawBar(e,x1,y,x2,p,color)
        p=clamp(p or 0,0,100); local width=math.max(1,x2-x1+1); local filled=math.floor(width*p/100+0.5)
        if filled>0 then fill(e,x1,y,x1+filled-1,y,color) end
        if filled<width then fill(e,x1+filled,y,x2,y,C.panel) end
    end

    local function adminNav(e)
        if mode~="admin" or e.w<32 or e.h<14 then return 0 end
        local items={{"nav_overview","HOME"},{"nav_doors","DOORS"},{"nav_power","POWER"},{"nav_sensors","SENSORS"},{"nav_fleet","FLEET"}}
        local left,right,gap=2,e.w-1,1
        local usable=right-left+1-gap*(#items-1); local cell=math.floor(usable/#items); local y=e.h-1
        for i,item in ipairs(items) do
            local x1=left+(i-1)*(cell+gap); local x2=i==#items and right or x1+cell-1
            button(e,item[1],x1,y,x2,e.h,item[2],true,nil,C.panel,C.text)
        end
        return 2
    end

    local function fleetCounts(env)
        local online,total=0,0
        for _,m in pairs(stateOf(env).fleet or {}) do total=total+1; if m.online~=false then online=online+1 end end
        return online,total
    end

    local function renderOverview(e,env,meta)
        prep(e); header(e,"COMMAND CENTER",gameTime())
        local raw,main=powerState(env,meta,false); local p=percent(main); local sensors=globalSensors(env); local s=stateOf(env)
        local doors=s.doors and s.doors.doors or {}; local open=0; for _,d in ipairs(doors) do if d.open then open=open+1 end end
        local online,total=fleetCounts(env); local ctx,cc=context(env); local bottom=e.h-3
        if e.w>=45 and bottom>=16 then
            local split=math.floor(e.w*0.56)
            put(e,2,5,"BASE TIME",C.dim); drawClock(e,7,2,split-2); center(e,13,ctx,cc,nil,2,split-2); line(e,15,"DAY",gameDay(),C.text,2)
            put(e,split+1,5,"POWER",C.dim)
            if p then
                local pc=p>=60 and C.good or (p>=25 and C.warn or C.bad)
                put(e,split+1,7,string.format("%.1f%%",p),pc); drawBar(e,split+1,9,e.w-2,p,pc)
                put(e,split+1,11,"+"..fmtFE(main.input,true),C.good); put(e,split+1,12,"-"..fmtFE(main.output,true),C.warn)
            else put(e,split+1,7,"ONLINE",C.good) end
            rule(e,17,2,e.w-1)
            line(e,19,"FLEET",tostring(online).."/"..tostring(total).." ONLINE",online==total and C.good or C.warn,2)
            line(e,21,"SENSORS",tostring(#sensors).." LIVE",#sensors>0 and C.good or C.warn,2)
            line(e,23,"DOORS",#doors==0 and "NOT CONFIGURED" or (tostring(open).." OPEN / "..tostring(#doors).." TOTAL"),#doors==0 and C.dim or C.good,2)
            line(e,19,"VERSION",tostring(env and env.version or "?"),C.text,split+1)
            line(e,21,"POWER SRC",tostring(tonumber(raw.onlineSources) or 0),C.text,split+1)
            line(e,23,"SYNC",upper((s.update and s.update.syncResult) or "AUTO"),C.good,split+1)
        else
            center(e,5,ctx,cc,nil,2,e.w-1); line(e,7,"FLEET",tostring(online).."/"..tostring(total),online==total and C.good or C.warn)
            line(e,8,"SENSORS",tostring(#sensors),#sensors>0 and C.good or C.warn); line(e,9,"DOORS",#doors==0 and "NONE" or tostring(#doors),C.text)
            if p then line(e,11,"POWER",string.format("%.1f%%",p),C.good) end
        end
        adminNav(e)
    end

    local function displayDoorName(d,env)
        local name=tostring(d.name or "")
        if name~="" and not name:match("^DOOR%s+%d+") then return upper(name) end
        local src=sourceName(d._source or d.source,env)
        if src~="ROOM PANEL" and src~="MAIN BASE" then return src end
        if d.side then return nice(d.side).." DOOR" end
        return "LOCAL DOOR"
    end

    local function drawDoorTiles(e,env,list,localOnly,readonly,top,bottom)
        local cols=e.w>=52 and 2 or 1; local rows=math.max(1,math.ceil(#list/cols)); local gap=1
        local cellW=math.floor((e.w-2-(cols-1)*gap)/cols); local cellH=math.max(5,math.floor((bottom-top+1-(rows-1)*gap)/rows))
        for i,d in ipairs(list) do
            local col=(i-1)%cols; local row=math.floor((i-1)/cols); local x1=2+col*(cellW+gap); local x2=math.min(e.w-1,x1+cellW-1); local y1=top+row*(cellH+gap); local y2=math.min(bottom,y1+cellH-1)
            local bg=d.online==false and C.panel or (d.open and C.good or C.action); local fg=d.open and colors.black or C.text; local state=d.online==false and "OFFLINE" or (d.open and "OPEN" or "CLOSED")
            fill(e,x1,y1,x2,y2,bg); center(e,y1+1,displayDoorName(d,env),fg,bg,x1+2,x2-2); center(e,math.min(y2,y1+3),state,fg,bg,x1+2,x2-2)
            if not readonly then register(e,{name=localOnly and "door_toggle_local" or "door_toggle",x1=x1,y1=y1,x2=x2,y2=y2,enabled=d.online~=false,label=state,data={_source=d._source or d.source,target=d.target,side=d.side,id=d.id}}) end
        end
    end

    local function drawSensorStrip(e,meta,top)
        local sensors=localSensors(meta); local devices=localDevices(meta)
        if top > e.h then return end
        rule(e,top,2,e.w-1); top=top+1
        if #sensors>0 then
            put(e,2,top,"LOCAL SENSORS  "..tostring(#sensors),C.good)
            local y=top+1
            for i=1,math.min(#sensors,2) do
                if y>e.h then break end
                local sensor=sensors[i]; local metrics=sensorMetrics(sensor); local value=#metrics>0 and (metrics[1][1].." "..nice(metrics[1][2])) or "ONLINE"
                put(e,2,y,sensorTitle(sensor).."  "..value,i==1 and C.text or C.dim); y=y+1
            end
        else
            put(e,2,top,"LOCAL SENSORS  0",C.warn)
            if #devices>0 and top+1<=e.h then
                put(e,2,top+1,"DETECTED DEVICES  "..tostring(#devices),C.dim)
                local names={}
                for i=1,math.min(2,#devices) do names[#names+1]=nice(devices[i].type or devices[i].name) end
                if #names>0 and top+2<=e.h then put(e,2,top+2,table.concat(names," / "),C.dim) end
            elseif top+1<=e.h then put(e,2,top+1,"NO PERIPHERALS VISIBLE TO THIS PC",C.dim) end
        end
    end

    local function candidateControllers(candidates)
        local order,groups={},{}
        for _,c in ipairs(candidates or {}) do
            local key=tostring(c.target or "computer")
            if not groups[key] then groups[key]={}; order[#order+1]=key end
            groups[key][#groups[key]+1]=c
        end
        table.sort(order,function(a,b)
            if a=="computer" then return false end
            if b=="computer" then return true end
            return a<b
        end)
        return order,groups
    end

    local function renderRoom(e,env,meta)
        prep(e); header(e,"ROOM CONTROL",gameTime())
        local doors=localDoors(env,meta); local sensors=localSensors(meta); local ctx,cc=roomContext(env,meta); put(e,2,5,ctx,cc)
        if #doors>0 then
            local sensorRows=#sensors>0 and 5 or 4; local bottom=math.max(10,e.h-sensorRows)
            drawDoorTiles(e,env,doors,true,false,7,bottom)
            drawSensorStrip(e,meta,bottom+1)
            return
        end

        local candidates=localCandidates(meta)
        if #candidates==0 then
            center(e,8,"NO DOOR CONTROLLER FOUND",C.warn,nil,2,e.w-1)
            center(e,10,"ATTACH REDSTONE INTEGRATOR OR DOOR",C.dim,nil,2,e.w-1)
            drawSensorStrip(e,meta,math.max(13,e.h-5))
            return
        end

        local order,groups=candidateControllers(candidates); local pageKey=e.name..":controller"; local controllerIndex=clamp(pages[pageKey] or 1,1,#order); pages[pageKey]=controllerIndex
        local controller=order[controllerIndex]; local list=groups[controller] or {}
        local native
        for _,c in ipairs(list) do if c.kind=="door" or c.side==nil then native=c; break end end

        if native then
            put(e,2,7,"DOOR CONTROLLER FOUND",C.good)
            put(e,2,8,nice(native.type or native.controller or native.target),C.dim)
            button(e,"door_register_local",3,10,e.w-2,14,"USE THIS DOOR",true,{target=native.target,side=native.side,name=computerName()~="ROOM PANEL" and computerName() or "LOCAL DOOR"},C.action)
            if #order>1 then button(e,"setup_next_controller",3,16,e.w-2,17,"OTHER DEVICE",true,{key=pageKey,count=#order},C.panel) end
            drawSensorStrip(e,meta,math.max(19,e.h-5))
            return
        end

        put(e,2,7,"REDSTONE DOOR SETUP",C.good)
        put(e,2,8,controller=="computer" and "THIS COMPUTER" or nice((list[1] and (list[1].type or list[1].controller)) or controller),C.dim)
        put(e,2,10,"WHICH SIDE GOES TO THE DOOR?",C.text)
        local cols=3; local left,right,gap=2,e.w-1,1; local usable=right-left+1-gap*(cols-1); local cellW=math.floor(usable/cols)
        for i,c in ipairs(list) do
            local col=(i-1)%cols; local row=math.floor((i-1)/cols); if row>=2 then break end
            local x1=left+col*(cellW+gap); local x2=col==cols-1 and right or x1+cellW-1; local y1=12+row*4
            local label=nice(c.side or c.label or "OUTPUT"); local doorName=computerName()~="ROOM PANEL" and computerName() or (label.." DOOR")
            button(e,"door_register_local",x1,y1,x2,y1+2,label,true,{target=c.target,side=c.side,name=doorName},C.action)
        end
        if #order>1 then button(e,"setup_next_controller",3,20,e.w-2,21,"OTHER DEVICE",true,{key=pageKey,count=#order},C.panel) end
        drawSensorStrip(e,meta,math.max(#order>1 and 22 or 20,e.h-5))
    end

    local function renderDoors(e,env,meta,localOnly,readonly)
        prep(e); local list=localOnly and localDoors(env,meta) or (stateOf(env).doors and stateOf(env).doors.doors or {})
        header(e,localOnly and "LOCAL DOORS" or "DOORS",gameTime())
        if #list==0 then center(e,math.floor((e.h-3)/2),"NO DOORS CONFIGURED",C.dim,nil,2,e.w-1) else drawDoorTiles(e,env,list,localOnly,readonly,5,e.h-(mode=="admin" and 3 or 1)) end
        adminNav(e)
    end

    local function renderSensors(e,env,meta,localOnly)
        prep(e); header(e,localOnly and "LOCAL SENSORS" or "SENSORS",gameTime())
        local list=localOnly and localSensors(meta) or globalSensors(env); local bottom=e.h-(mode=="admin" and 3 or 1)
        if #list==0 then
            center(e,7,"NO SENSOR TELEMETRY",C.warn,nil,2,e.w-1)
            if localOnly then
                local devices=localDevices(meta); line(e,10,"DEVICES",tostring(#devices),C.dim)
                local y=12; for i=1,math.min(#devices,4) do put(e,2,y,nice(devices[i].type or devices[i].name),C.dim); y=y+1 end
            end
            adminNav(e); return
        end
        local cols=e.w>=50 and 2 or 1; local rowsPerCol=math.max(1,math.floor((bottom-5)/6)); local perPage=rowsPerCol*cols; local maxPage=math.max(1,math.ceil(#list/perPage)); local key=e.name..":sensors:"..tostring(localOnly); pages[key]=clamp(pages[key] or 1,1,maxPage); local page=pages[key]; local first=(page-1)*perPage+1
        for slot=0,perPage-1 do
            local sensor=list[first+slot]; if not sensor then break end
            local col=slot%cols; local row=math.floor(slot/cols); local colW=math.floor(e.w/cols); local x1=2+col*colW; local x2=col==cols-1 and e.w-1 or colW; local y=5+row*6
            put(e,x1,y,sensorTitle(sensor),C.text); put(e,x1,y+1,localOnly and "LOCAL" or sourceName(sensor._source,env),C.dim)
            local metrics=sensorMetrics(sensor)
            if #metrics==0 then put(e,x1,y+3,"ONLINE",C.good) else for j=1,math.min(2,#metrics) do put(e,x1,y+1+j,metrics[j][1].."  "..nice(metrics[j][2]),j==1 and C.good or C.text) end end
            rule(e,y+5,x1,x2)
        end
        if maxPage>1 then center(e,bottom,tostring(page).." / "..tostring(maxPage).."  TOUCH EDGES",C.dim,nil,2,e.w-1) end
        adminNav(e)
    end

    local function renderPower(e,env,meta,localOnly)
        prep(e); header(e,localOnly and "LOCAL POWER" or "POWER",gameTime())
        local raw,main=powerState(env,meta,localOnly); local sources=tonumber(raw.onlineSources) or 0; local bottom=e.h-(mode=="admin" and 3 or 1)
        if sources<=0 then center(e,math.floor(bottom/2),"NO POWER TELEMETRY",C.dim,nil,2,e.w-1); adminNav(e); return end
        local p=percent(main); local color=not p and C.good or (p>=60 and C.good or (p>=25 and C.warn or C.bad)); local y=5
        if p then center(e,y,string.format("%.1f%%",p),color,nil,2,e.w-1); drawBar(e,3,y+2,e.w-2,p,color); y=y+5 else center(e,y,"POWER ONLINE",C.good,nil,2,e.w-1); y=y+3 end
        line(e,y,"STORED",fmtFE(main.stored,false)); y=y+1; line(e,y,"CAPACITY",fmtFE(main.capacity,false)); y=y+2
        line(e,y,"INPUT","+ "..fmtFE(main.input,true),C.good); y=y+1; line(e,y,"OUTPUT","- "..fmtFE(main.output,true),C.warn); y=y+2; rule(e,y); y=y+2
        line(e,y,"SOURCES",tostring(sources),C.text); y=y+2
        for i,m in ipairs(raw.matrices or {}) do if y>bottom-1 then break end; put(e,2,y,"MATRIX "..i,C.text); put(e,2,y+1,(percent(m) and string.format("%.1f%%",percent(m)) or "ONLINE").."  "..fmtFE(m.stored,false),C.good); y=y+3 end
        for i,f in ipairs(raw.fluxNetworks or {}) do if y>bottom-1 then break end; put(e,2,y,"FLUX "..i.."  "..nice(f.networkName or "NETWORK"),C.text); y=y+2 end
        adminNav(e)
    end

    local function renderFleet(e,env)
        prep(e); header(e,"FLEET",gameTime()); local fleet=stateOf(env).fleet or {}; local ids={}; for id in pairs(fleet) do ids[#ids+1]=id end; table.sort(ids,function(a,b)return tostring(a)<tostring(b)end)
        local online,total=fleetCounts(env); line(e,5,"ONLINE",tostring(online).."/"..tostring(total),online==total and C.good or C.warn); rule(e,7); local bottom=e.h-(mode=="admin" and 3 or 1); local y=9
        for _,id in ipairs(ids) do
            if y>bottom-1 then break end
            local m=fleet[id]; local display=m.name
            if not display or tostring(display):match("^KIMI[%s%-]?%d+$") then display=(m.role=="node" and "REMOTE NODE" or "ROOM PANEL") end
            put(e,2,y,upper(display),m.online==false and C.bad or C.good)
            put(e,2,y+1,upper(tostring(m.version or "?")).."  "..upper(tostring(m.updateStatus or "")),C.dim)
            y=y+3
        end
        adminNav(e)
    end

    local function renderStatus(e,env,meta)
        prep(e); header(e,"BASE STATUS",gameDay()); local ctx,cc=context(env); local online,total=fleetCounts(env); local sensors=globalSensors(env)
        drawClock(e,5); local y=e.h>=18 and 11 or 8; center(e,y,ctx,cc,nil,2,e.w-1); center(e,y+2,tostring(online).."/"..tostring(total).." COMPUTERS   "..tostring(#sensors).." SENSORS",C.dim,nil,2,e.w-1)
    end

    local function capabilities(env,meta)
        local s=stateOf(env); local lp=meta and meta.localState and meta.localState.power or {}
        return {localDoors=localDoors(env,meta),localSensors=localSensors(meta),sensors=globalSensors(env),doors=s.doors and s.doors.doors or {},hasPower=(tonumber(s.power and s.power.onlineSources) or 0)>0,hasLocalPower=(tonumber(lp.onlineSources) or 0)>0}
    end

    local function autoViews(env,meta)
        local c=capabilities(env,meta); local v={}
        if mode=="admin" then
            v[#v+1]="overview"; if c.hasPower then v[#v+1]="power" end; if #c.sensors>0 then v[#v+1]="sensors" end; v[#v+1]="fleet"; if #c.doors>0 then v[#v+1]="doors" end
        else
            v[#v+1]="room"; if #c.localSensors>0 then v[#v+1]="sensors_local" end; if c.hasLocalPower then v[#v+1]="power_local" end; v[#v+1]="status"
        end
        return v
    end

    local function plan(env,meta)
        local available=autoViews(env,meta); local out={}
        for i,e in ipairs(monitors) do out[e.name]=manualViews[e.name] or available[((i-1)%#available)+1] end
        return out
    end

    local renderers={overview=renderOverview,room=renderRoom,status=renderStatus,doors=function(e,env,meta)renderDoors(e,env,meta,false,false)end,sensors=function(e,env,meta)renderSensors(e,env,meta,false)end,sensors_local=function(e,env,meta)renderSensors(e,env,meta,true)end,power=function(e,env,meta)renderPower(e,env,meta,false)end,power_local=function(e,env,meta)renderPower(e,env,meta,true)end,fleet=renderFleet}

    local function renderOne(e,view,env,meta) targets[e.name]={}; (renderers[view] or renderStatus)(e,env,meta or {}) end
    local function redraw(name)
        if not lastEnvelope then return end
        local assigned=plan(lastEnvelope,lastMeta or {})
        for _,e in ipairs(monitors) do if e.name==name then renderOne(e,manualViews[name] or assigned[name] or (mode=="admin" and "overview" or "room"),lastEnvelope,lastMeta or {}); return end end
    end

    local M={}
    function M.init(newCfg)
        cfg=newCfg or cfg or {}; monitors=detectMonitors(); term.clear(); term.setCursorPos(1,1)
        print("KIMI Adaptive Display v5"); print("Profile: "..tostring(mode).." / monitors: "..tostring(#monitors))
        for i,e in ipairs(monitors) do print(string.format("  %d) %s %dx%d scale %.1f",i,e.name,e.w,e.h,e.scale)) end
    end
    function M.render(env,meta)
        monitors=detectMonitors(); lastEnvelope,lastMeta=env,meta or {}; targets={}; local assigned=plan(env,lastMeta)
        for _,e in ipairs(monitors) do renderOne(e,assigned[e.name] or (mode=="admin" and "overview" or "room"),env,lastMeta) end
    end
    function M.onPeripheralChange() monitors=detectMonitors(); targets={} end
    function M.handleEvent(event,env,action)
        if type(event)~="table" or event[1]~="monitor_touch" then return end
        local name,x,y=event[2],tonumber(event[3]),tonumber(event[4]); if not x or not y then return end
        for _,t in ipairs(targets[name] or {}) do
            if t.enabled and x>=t.x1 and x<=t.x2 and y>=t.y1 and y<=t.y2 then
                local entry; for _,e in ipairs(monitors) do if e.name==name then entry=e; break end end
                if entry then fill(entry,t.x1,t.y1,t.x2,t.y2,colors.white); center(entry,math.floor((t.y1+t.y2)/2),t.label or "OK",colors.black,colors.white,t.x1+1,t.x2-1) end
                local n=t.name
                if n=="nav_overview" then manualViews[name]="overview"; redraw(name)
                elseif n=="nav_doors" then manualViews[name]="doors"; redraw(name)
                elseif n=="nav_power" then manualViews[name]="power"; redraw(name)
                elseif n=="nav_sensors" then manualViews[name]="sensors"; redraw(name)
                elseif n=="nav_fleet" then manualViews[name]="fleet"; redraw(name)
                elseif n=="setup_next_controller" and t.data then pages[t.data.key]=((pages[t.data.key] or 1)%t.data.count)+1; redraw(name)
                elseif n=="door_register_local" and t.data then if action then action("__local_doors","register_local",t.data) end
                elseif n=="door_toggle_local" and t.data then if action then action("__local_doors","toggle",t.data) end
                elseif n=="door_toggle" and t.data then if action then action("doors","toggle",t.data) end
                end
                return true
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
