local Adaptive={}

local function clamp(v,lo,hi) v=tonumber(v) or lo; if v<lo then return lo elseif v>hi then return hi end; return v end
local function upper(v) return tostring(v or ""):upper() end
local function nice(v)
    local s=tostring(v or ""):gsub("minecraft:",""):gsub("[_%-]"," "):gsub("(%l)(%u)","%1 %2")
    return upper(s)
end
local function gameTime()
    local ok,value=pcall(os.time,"ingame"); local t=ok and tonumber(value) or 0; local h=math.floor(t%24); local m=math.floor(((t%24)-h)*60); return string.format("%02d:%02d",h,m)
end
local function fmtNumber(v)
    local n=tonumber(v); if not n then return "?" end; local a=math.abs(n)
    if a>=1e15 then return string.format("%.1fP",n/1e15) elseif a>=1e12 then return string.format("%.1fT",n/1e12) elseif a>=1e9 then return string.format("%.1fG",n/1e9) elseif a>=1e6 then return string.format("%.1fM",n/1e6) elseif a>=1e3 then return string.format("%.1fK",n/1e3) end
    return math.abs(n-math.floor(n))>.01 and string.format("%.2f",n) or tostring(math.floor(n))
end
local function fmtFE(v,rate) local s=fmtNumber(v); return s=="?" and s or s.." FE"..(rate and "/t" or "") end

function Adaptive.create(options)
    options=options or {}; local mode=options.mode or "wall"
    local cfg,monitors,lastEnvelope,lastMeta=nil,{},nil,nil
    local targets,manualViews,pages,toasts={},{},{},{}
    local C={bg=colors.black,panel=colors.gray,dim=colors.lightGray,text=colors.white,good=colors.lime,warn=colors.orange,bad=colors.red,action=colors.blue,accent=colors.cyan or colors.lightBlue}

    local function computerName()
        local label=type(os.getComputerLabel)=="function" and os.getComputerLabel() or nil
        if label and tostring(label):match("%S") and not tostring(label):match("^KIMI[%s%-]?%d+$") then return upper(label) end
        local configured=cfg and cfg.name
        if configured and tostring(configured):match("%S") and not tostring(configured):match("^KIMI[%s%-]?%d+$") then return upper(configured) end
        return mode=="admin" and "MAIN BASE" or "ROOM PANEL"
    end

    local function detectMonitors()
        local out={}
        for _,name in ipairs(peripheral.getNames()) do
            if peripheral.hasType(name,"monitor") then
                local mon=peripheral.wrap(name)
                if mon then
                    local scale=1.0; pcall(mon.setTextScale,scale); local ok,w,h=pcall(mon.getSize)
                    if ok and tonumber(w) and tonumber(h) then
                        w,h=tonumber(w),tonumber(h)
                        if w<18 or h<8 then scale=.5; pcall(mon.setTextScale,scale); local ok2,w2,h2=pcall(mon.getSize); if ok2 then w,h=tonumber(w2) or w,tonumber(h2) or h end end
                        out[#out+1]={name=name,mon=mon,w=w,h=h,scale=scale,area=w*h,class=w>=45 and "wide" or (w>=25 and "medium" or "small")}
                    end
                end
            end
        end
        table.sort(out,function(a,b) if a.area~=b.area then return a.area>b.area end; if a.w~=b.w then return a.w>b.w end; return a.name<b.name end); return out
    end

    local function prep(e) pcall(e.mon.setTextScale,e.scale); e.mon.setBackgroundColor(C.bg); e.mon.setTextColor(C.text); e.mon.clear(); e.mon.setCursorPos(1,1) end
    local function put(e,x,y,text,fg,bg)
        if y<1 or y>e.h or x>e.w then return end; x=math.max(1,x); text=tostring(text or "")
        e.mon.setCursorPos(x,y); e.mon.setTextColor(fg or C.text); e.mon.setBackgroundColor(bg or C.bg); e.mon.write(text:sub(1,math.max(0,e.w-x+1))); e.mon.setBackgroundColor(C.bg)
    end
    local function fill(e,x1,y1,x2,y2,bg)
        x1,x2=math.max(1,x1),math.min(e.w,x2); y1,y2=math.max(1,y1),math.min(e.h,y2); if x2<x1 or y2<y1 then return end
        for y=y1,y2 do put(e,x1,y,string.rep(" ",x2-x1+1),C.text,bg) end
    end
    local function center(e,y,text,fg,bg,x1,x2)
        x1,x2=x1 or 1,x2 or e.w; local width=math.max(1,x2-x1+1); text=tostring(text or ""); if #text>width then text=text:sub(1,width) end
        put(e,x1+math.max(0,math.floor((width-#text)/2)),y,text,fg,bg)
    end
    local function rule(e,y,x1,x2,color) x1,x2=x1 or 2,x2 or e.w-1; if x2>=x1 then put(e,x1,y,string.rep("-",x2-x1+1),color or C.panel) end end
    local function line(e,y,label,value,color,x) x=x or 2; local p=label and upper(label).."  " or ""; put(e,x,y,p,C.dim); put(e,x+#p,y,tostring(value or ""),color or C.text) end
    local function header(e,title,right)
        put(e,2,1,upper(title),C.text); if right then put(e,math.max(2,e.w-#tostring(right)-1),1,tostring(right),C.dim) end
        put(e,2,2,computerName(),C.dim); rule(e,3,1,e.w,C.panel)
    end
    local function register(e,t) targets[e.name]=targets[e.name] or {}; targets[e.name][#targets[e.name]+1]=t end
    local function button(e,name,x1,y1,x2,y2,text,enabled,data,bg,fg)
        enabled=enabled~=false; x1,x2=math.max(2,x1),math.min(e.w-1,x2); y1,y2=math.max(1,y1),math.min(e.h,y2); if x2<x1 or y2<y1 then return end
        bg=enabled and (bg or C.action) or C.panel; fg=enabled and (fg or C.text) or C.dim; fill(e,x1,y1,x2,y2,bg)
        center(e,math.floor((y1+y2)/2),text,fg,bg,math.min(x2,x1+2),math.max(x1,x2-2)); register(e,{name=name,x1=x1,y1=y1,x2=x2,y2=y2,enabled=enabled,data=data,label=text})
    end
    local function stateOf(env) return env and env.state or {} end
    local function localSource(meta) return meta and meta.localServer and "server" or tostring(os.getComputerID()) end

    local function sourceName(source,env)
        source=tostring(source or "server"); if source=="server" then return "MAIN BASE" end
        local s=stateOf(env); local item=(s.sources and s.sources[source]) or (s.fleet and (s.fleet[source] or s.fleet[tonumber(source)]))
        if item and item.name and not tostring(item.name):match("^KIMI[%s%-]?%d+$") then return upper(item.name) end
        if item and item.role=="node" then return "REMOTE NODE" end; return "ROOM PANEL"
    end
    local function localDoors(env,meta)
        local out,seen={},{}; local localState=meta and meta.localState or {}
        for _,d in ipairs(localState.doors and localState.doors.localDoors or {}) do local key=tostring(d.key or tostring(d.target).."|"..tostring(d.side or "")); local item={}; for k,v in pairs(d) do item[k]=v end; item._source=localSource(meta); item.source=item._source; out[#out+1]=item; seen[key]=true end
        for _,d in ipairs(stateOf(env).doors and stateOf(env).doors.doors or {}) do if tostring(d._source or d.source or "server")==localSource(meta) then local key=tostring(d.key or tostring(d.target).."|"..tostring(d.side or "")); if not seen[key] then out[#out+1]=d; seen[key]=true end end end
        return out
    end
    local function localCandidates(meta)
        local s=meta and meta.localState or {}; local raw=s.doors and s.doors.candidates or {}; local dedicated,computer={},{}
        for _,c in ipairs(raw) do if c.localConfigured~=true then if tostring(c.target)=="computer" then computer[#computer+1]=c else dedicated[#dedicated+1]=c end end end
        -- Dedicated peripherals are what the player deliberately placed. Built-in
        -- computer redstone is only the fallback when no controller exists.
        if #dedicated>0 then return dedicated end; return computer
    end
    local function localSensors(meta) local s=meta and meta.localState or {}; return s.attachments and s.attachments.sensors or {} end
    local function localDevices(meta) local s=meta and meta.localState or {}; return s.attachments and s.attachments.devices or {} end
    local function globalSensors(env) return stateOf(env).attachments and stateOf(env).attachments.sensors or {} end
    local function globalDevices(env) return stateOf(env).attachments and stateOf(env).attachments.devices or {} end

    local function sensorTitle(sensor)
        local t=nice(sensor and sensor.type or "sensor"); if t:find("ENVIRONMENT",1,true) then return "ENVIRONMENT" elseif t:find("PLAYER",1,true) then return "PLAYER DETECTOR" elseif t:find("GEO",1,true) then return "GEO SCANNER" elseif t:find("BLOCK",1,true) then return "BLOCK READER" end; return t
    end
    local function sensorMetric(sensor)
        local m=sensor and sensor.metrics or {}; local order={{"temperature","TEMP"},{"radiationRaw","RADIATION"},{"radiationText","RADIATION"},{"solarRadiation","SOLAR"},{"onlinePlayers","PLAYERS"},{"biome","BIOME"},{"dimension","DIMENSION"},{"humidity","HUMIDITY"},{"pressure","PRESSURE"},{"maxScanRadius","SCAN RANGE"},{"entityCount","ENTITIES"}}
        for _,pair in ipairs(order) do if m[pair[1]]~=nil then return pair[2],nice(m[pair[1]]) end end
        return "STATUS",nice(sensor and sensor.summary or "ONLINE")
    end
    local function deviceTypes(devices)
        local out,seen={},{}
        for _,d in ipairs(devices or {}) do
            local t=nice(d.type or (d.types and d.types[1]) or "UNKNOWN")
            if t~="MONITOR" and t~="MODEM" and not seen[t] then seen[t]=true; out[#out+1]=t end
        end
        table.sort(out); return out
    end

    local function choosePower(raw)
        raw=raw or {}; local best,bestScore=nil,-1
        local function consider(p) if type(p)~="table" then return end; local cap=tonumber(p.capacity) or 0; local stored=tonumber(p.stored) or 0; local input=tonumber(p.input) or 0; local output=tonumber(p.output) or 0; local score=(cap>0 and 1e9 or 0)+(stored>0 and 1e7 or 0)+math.abs(input)+math.abs(output); if score>bestScore then best,bestScore=p,score end end
        for _,p in ipairs(raw.matrices or {}) do consider(p) end; for _,p in ipairs(raw.fluxNetworks or {}) do consider(p) end; for _,p in ipairs(raw.energyDetectors or {}) do consider(p) end; consider(raw); return best or raw
    end
    local function powerState(env,meta,localOnly) local raw=localOnly and meta and meta.localState and meta.localState.power or stateOf(env).power; raw=raw or {}; return raw,choosePower(raw) end
    local function percent(p) local n=tonumber(p and p.filledPercentage); if n then if n<=1 then n=n*100 end; return clamp(n,0,100) end; local st,cap=tonumber(p and p.stored),tonumber(p and p.capacity); if st and cap and cap>0 then return clamp(st/cap*100,0,100) end end
    local function bar(e,x1,y,x2,p,color) local width=x2-x1+1; local full=math.floor(width*clamp(p or 0,0,100)/100+.5); if full>0 then fill(e,x1,y,x1+full-1,y,color) end; if full<width then fill(e,x1+full,y,x2,y,C.panel) end end

    local function adminNav(e)
        if mode~="admin" or e.w<42 or e.h<15 then return 0 end
        local items={{"nav_home","HOME"},{"nav_doors","DOORS"},{"nav_power","POWER"},{"nav_sensors","SENSORS"},{"nav_fleet","FLEET"}}
        local left,right,gap=2,e.w-1,1; local cell=math.floor((right-left+1-gap*(#items-1))/#items); local y=e.h-1
        for i,item in ipairs(items) do local x1=left+(i-1)*(cell+gap); local x2=i==#items and right or x1+cell-1; button(e,item[1],x1,y,x2,e.h,item[2],true,nil,C.panel,C.text) end; return 2
    end

    local function drawSensorStrip(e,meta,y)
        local sensors=localSensors(meta); local devices=localDevices(meta)
        rule(e,y,2,e.w-1); y=y+1
        if #sensors>0 then
            put(e,2,y,"SENSORS",C.dim); put(e,11,y,tostring(#sensors).." ONLINE",C.good)
            local sensor=sensors[1]; local label,value=sensorMetric(sensor); put(e,2,y+1,sensorTitle(sensor),C.text); put(e,2,y+2,label.."  "..value,C.good)
        else
            put(e,2,y,"SENSORS  0",C.warn); put(e,2,y+1,"PERIPHERALS  "..tostring(#devices),C.dim)
            local types=deviceTypes(devices); if #types>0 then put(e,2,y+2,table.concat(types," / "):sub(1,e.w-3),C.text) else put(e,2,y+2,"NO DATA PERIPHERALS DETECTED",C.dim) end
        end
    end

    local function groupCandidates(candidates)
        local order,groups={},{}
        for _,c in ipairs(candidates or {}) do local key=tostring(c.target); if not groups[key] then groups[key]={}; order[#order+1]=key end; groups[key][#groups[key]+1]=c end
        table.sort(order,function(a,b)
            local ga,gb=groups[a][1],groups[b][1]; local pa=ga and ga.kind=="native_door" and 0 or 1; local pb=gb and gb.kind=="native_door" and 0 or 1; if pa~=pb then return pa<pb end; return a<b
        end); return order,groups
    end

    local function renderRoom(e,env,meta)
        prep(e); header(e,"ROOM CONTROL",gameTime()); local doors=localDoors(env,meta); local sensors=localSensors(meta)
        put(e,2,5,meta and meta.connected==false and "MAIN BASE OFFLINE" or "MAIN BASE LINKED",meta and meta.connected==false and C.warn or C.good)
        if #doors>0 then
            local d=doors[1]; local state=d.online==false and "OFFLINE" or (d.open and "OPEN" or "CLOSED"); local color=d.online==false and C.panel or (d.open and C.good or C.action)
            center(e,8,upper(d.name or "LOCAL DOOR"),C.text,nil,2,e.w-1); center(e,10,state,d.open and C.good or C.text,nil,2,e.w-1)
            button(e,"door_toggle_local",3,12,e.w-2,math.max(15,e.h-7),d.open and "CLOSE DOOR" or "OPEN DOOR",d.online~=false,{_source=localSource(meta),target=d.target,side=d.side,id=d.id},color,d.open and colors.black or C.text)
            drawSensorStrip(e,meta,e.h-5); return
        end

        local candidates=localCandidates(meta)
        put(e,2,7,"DOOR SETUP",C.text)
        if #candidates==0 then
            center(e,10,"NO DOOR ACTUATOR FOUND",C.warn,nil,2,e.w-1); center(e,12,"CONNECT REDSTONE / RELAY / DOOR PERIPHERAL",C.dim,nil,2,e.w-1); drawSensorStrip(e,meta,e.h-5); return
        end
        local order,groups=groupCandidates(candidates); local key=e.name..":setup_controller"; pages[key]=clamp(pages[key] or 1,1,#order); local target=order[pages[key]]; local list=groups[target] or {}; local first=list[1]
        put(e,2,8,first and nice(first.type or first.controller) or "ACTUATOR",C.dim)
        if first and (first.kind=="native_door" or first.kind=="enabled_actuator" or first.kind=="active_actuator") and #list==1 then
            center(e,10,"KIMI FOUND A DIRECT DOOR ACTUATOR",C.good,nil,2,e.w-1)
            button(e,"door_register_local",3,12,e.w-2,16,"USE THIS DOOR",true,{target=first.target,side=first.side,name=computerName()},C.action)
        else
            center(e,10,"WHICH OUTPUT OPENS THE DOOR?",C.dim,nil,2,e.w-1)
            local left,right,gap=3,e.w-2,1; local cell=math.floor((right-left+1-gap*2)/3); local top=12
            for i,c in ipairs(list) do if i>6 then break end; local col=(i-1)%3; local row=math.floor((i-1)/3); local x1=left+col*(cell+gap); local x2=col==2 and right or x1+cell-1; local y1=top+row*4
                button(e,"door_register_local",x1,y1,x2,y1+2,nice(c.side or c.label or "OUTPUT"),true,{target=c.target,side=c.side,name=computerName()},C.action)
            end
        end
        if #order>1 then button(e,"setup_next",3,e.h-9,e.w-2,e.h-7,"OTHER CONTROLLER",true,{key=key,count=#order},C.panel) end
        drawSensorStrip(e,meta,e.h-5)
    end

    local function renderPower(e,env,meta,localOnly)
        prep(e); header(e,localOnly and "LOCAL POWER" or "POWER",gameTime()); local raw,main=powerState(env,meta,localOnly); local sources=tonumber(raw.onlineSources) or 0
        if sources<=0 then center(e,math.floor(e.h/2),"NO POWER TELEMETRY",C.dim,nil,2,e.w-1); adminNav(e); return end
        local p=percent(main); local color=not p and C.good or (p>=60 and C.good or (p>=25 and C.warn or C.bad)); local y=5
        if p then center(e,y,string.format("%.1f%%",p),color,nil,2,e.w-1); bar(e,3,y+2,e.w-2,p,color); y=y+5 end
        line(e,y,"STORED",fmtFE(main.stored,false)); line(e,y+1,"CAPACITY",fmtFE(main.capacity,false)); line(e,y+3,"INPUT","+ "..fmtFE(main.input,true),C.good); line(e,y+4,"OUTPUT","- "..fmtFE(main.output,true),C.warn); rule(e,y+6); line(e,y+8,"SOURCES",sources,C.text)
        local yy=y+10; for i,m in ipairs(raw.matrices or {}) do if yy>e.h-3 then break end; put(e,2,yy,"MATRIX "..i,C.text); put(e,2,yy+1,(percent(m) and string.format("%.1f%%",percent(m)) or "ONLINE").."  "..fmtFE(m.stored,false),C.good); yy=yy+3 end
        adminNav(e)
    end

    local function renderSensors(e,env,meta,localOnly)
        prep(e); header(e,localOnly and "LOCAL SENSORS" or "SENSORS",gameTime()); local sensors=localOnly and localSensors(meta) or globalSensors(env); local devices=localOnly and localDevices(meta) or globalDevices(env); local bottom=e.h-(mode=="admin" and 3 or 1)
        line(e,5,"SENSORS",#sensors,#sensors>0 and C.good or C.warn); line(e,6,"PERIPHERALS",#devices,C.dim); rule(e,8)
        if #sensors==0 then
            center(e,10,"NO SENSOR CLASSIFIED",C.warn,nil,2,e.w-1); put(e,2,12,"DETECTED TYPES",C.dim); local types=deviceTypes(devices)
            local y=14; for _,t in ipairs(types) do if y>bottom then break end; put(e,3,y,t,C.text); y=y+2 end
            if #types==0 then center(e,14,"NO DATA PERIPHERALS VISIBLE TO THIS COMPUTER",C.dim,nil,2,e.w-1) end
            adminNav(e); return
        end
        local y=10
        for _,sensor in ipairs(sensors) do if y>bottom-3 then break end; put(e,2,y,sensorTitle(sensor),C.text); put(e,2,y+1,localOnly and "LOCAL" or sourceName(sensor._source,env),C.dim); local label,value=sensorMetric(sensor); put(e,2,y+2,label.."  "..value,C.good); rule(e,y+4); y=y+6 end
        adminNav(e)
    end

    local function renderFleet(e,env)
        prep(e); header(e,"FLEET",gameTime()); local fleet=stateOf(env).fleet or {}; local ids={}; for id in pairs(fleet) do ids[#ids+1]=id end; table.sort(ids,function(a,b)return tonumber(a or 0)<tonumber(b or 0)end)
        local online,total=0,0; for _,m in pairs(fleet) do total=total+1; if m.online~=false then online=online+1 end end
        line(e,5,"ONLINE",tostring(online).." / "..tostring(total),online==total and C.good or C.warn); line(e,6,"TARGET",tostring(env and env.version or "?"),C.text); rule(e,8); local y=10
        for _,id in ipairs(ids) do if y>e.h-3 then break end; local m=fleet[id]; local display=m.name; if not display or tostring(display):match("^KIMI[%s%-]?%d+$") then display=m.role=="server" and "MAIN BASE" or (m.role=="node" and "REMOTE NODE" or "ROOM PANEL") end
            put(e,2,y,upper(display),m.online==false and C.bad or C.good); put(e,2,y+1,upper(tostring(m.version or "UNKNOWN")).."  "..upper(tostring(m.updateStatus or "")),C.dim); y=y+3 end
        adminNav(e)
    end

    local function renderDoors(e,env,meta)
        prep(e); header(e,"DOORS",gameTime()); local list=stateOf(env).doors and stateOf(env).doors.doors or {}
        if #list==0 then center(e,math.floor(e.h/2)-1,"NO DOORS REGISTERED",C.dim,nil,2,e.w-1); center(e,math.floor(e.h/2)+1,"SET THEM UP ON EACH ROOM PANEL",C.good,nil,2,e.w-1); adminNav(e); return end
        local y=6
        for _,d in ipairs(list) do if y>e.h-5 then break end; local state=d.online==false and "OFFLINE" or (d.open and "OPEN" or "CLOSED"); put(e,2,y,upper(d.name or sourceName(d._source,env)),C.text); put(e,2,y+1,state,d.online==false and C.bad or (d.open and C.good or C.dim)); rule(e,y+3); y=y+5 end
        adminNav(e)
    end

    local function renderOverview(e,env,meta)
        prep(e); header(e,"COMMAND CENTER",gameTime()); local s=stateOf(env); local raw,main=powerState(env,meta,false); local p=percent(main); local sensors=globalSensors(env); local doors=s.doors and s.doors.doors or {}; local fleet=s.fleet or {}
        local online,total=0,0; for _,m in pairs(fleet) do total=total+1; if m.online~=false then online=online+1 end end
        if e.w>=45 and e.h>=20 then
            local split=math.floor(e.w*.55); put(e,2,5,"BASE",C.dim); center(e,7,gameTime(),C.text,nil,2,split-2); line(e,10,"FLEET",tostring(online).."/"..tostring(total),online==total and C.good or C.warn,2); line(e,12,"SENSORS",#sensors,#sensors>0 and C.good or C.warn,2); line(e,14,"DOORS",#doors,#doors>0 and C.good or C.dim,2)
            put(e,split+1,5,"POWER",C.dim); if p then put(e,split+1,7,string.format("%.1f%%",p),p>=60 and C.good or C.warn); bar(e,split+1,9,e.w-2,p,p>=60 and C.good or C.warn); put(e,split+1,11,"+"..fmtFE(main.input,true),C.good); put(e,split+1,12,"-"..fmtFE(main.output,true),C.warn) end
            rule(e,17); line(e,19,"VERSION",tostring(env and env.version or "?"),C.text); line(e,21,"FLEET SYNC",upper(s.update and s.update.syncResult or "AUTO"),C.good)
        else
            center(e,5,gameTime(),C.text,nil,2,e.w-1); line(e,8,"FLEET",tostring(online).."/"..tostring(total),online==total and C.good or C.warn); line(e,10,"SENSORS",#sensors,#sensors>0 and C.good or C.warn); if p then line(e,12,"POWER",string.format("%.1f%%",p),C.good) end
        end
        adminNav(e)
    end

    local function autoViews(env,meta)
        if mode=="admin" then
            local s=stateOf(env); local views={"overview"}; if tonumber(s.power and s.power.onlineSources or 0)>0 then views[#views+1]="power" end; if #(s.attachments and s.attachments.sensors or {})>0 then views[#views+1]="sensors" end; views[#views+1]="fleet"; if #(s.doors and s.doors.doors or {})>0 then views[#views+1]="doors" end; return views
        end
        local views={"room"}; if #localSensors(meta)>0 then views[#views+1]="sensors_local" end; return views
    end
    local renderers={room=renderRoom,overview=renderOverview,power=function(e,env,meta)renderPower(e,env,meta,false)end,power_local=function(e,env,meta)renderPower(e,env,meta,true)end,sensors=function(e,env,meta)renderSensors(e,env,meta,false)end,sensors_local=function(e,env,meta)renderSensors(e,env,meta,true)end,fleet=renderFleet,doors=renderDoors}
    local function plan(env,meta) local views=autoViews(env,meta); local out={}; for i,e in ipairs(monitors) do out[e.name]=manualViews[e.name] or views[((i-1)%#views)+1] end; return out end
    local function renderOne(e,view,env,meta) targets[e.name]={}; (renderers[view] or renderRoom)(e,env,meta or {}) end
    local function redraw(name)
        if not lastEnvelope then return end; local assigned=plan(lastEnvelope,lastMeta or {}); for _,e in ipairs(monitors) do if e.name==name then renderOne(e,manualViews[name] or assigned[name] or (mode=="admin" and "overview" or "room"),lastEnvelope,lastMeta or {}); return end end
    end

    local M={}
    function M.init(newCfg) cfg=newCfg or cfg or {}; monitors=detectMonitors(); term.clear(); term.setCursorPos(1,1); print("KIMI Adaptive Display v6"); print("Profile: "..mode.." / monitors: "..#monitors) end
    function M.render(env,meta) monitors=detectMonitors(); lastEnvelope,lastMeta=env,meta or {}; targets={}; local assigned=plan(env,lastMeta); for _,e in ipairs(monitors) do renderOne(e,assigned[e.name] or (mode=="admin" and "overview" or "room"),env,lastMeta) end end
    function M.onPeripheralChange() monitors=detectMonitors(); targets={} end
    function M.handleEvent(event,env,action)
        if type(event)~="table" or event[1]~="monitor_touch" then return end; local name,x,y=event[2],tonumber(event[3]),tonumber(event[4]); if not x or not y then return end
        for _,t in ipairs(targets[name] or {}) do
            if t.enabled and x>=t.x1 and x<=t.x2 and y>=t.y1 and y<=t.y2 then
                local entry; for _,e in ipairs(monitors) do if e.name==name then entry=e; break end end
                if entry then fill(entry,t.x1,t.y1,t.x2,t.y2,colors.white); center(entry,math.floor((t.y1+t.y2)/2),t.label or "OK",colors.black,colors.white,t.x1+2,t.x2-2) end
                local n=t.name
                if n=="nav_home" then manualViews[name]="overview"
                elseif n=="nav_doors" then manualViews[name]="doors"
                elseif n=="nav_power" then manualViews[name]="power"
                elseif n=="nav_sensors" then manualViews[name]="sensors"
                elseif n=="nav_fleet" then manualViews[name]="fleet"
                elseif n=="setup_next" and t.data then pages[t.data.key]=((pages[t.data.key] or 1)%t.data.count)+1
                elseif n=="door_register_local" and t.data then
                    local ok,result=action and action("__local_doors","register_local",t.data)
                    if ok~=false then manualViews[name]="room" else toasts[name]=tostring(result or "SETUP FAILED") end
                elseif n=="door_toggle_local" and t.data then if action then action("__local_doors","toggle",t.data) end
                end
                redraw(name); return true
            end
        end
    end
    return M
end

return Adaptive
