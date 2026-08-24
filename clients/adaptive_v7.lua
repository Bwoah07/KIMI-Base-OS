local Adaptive = {}

local function clamp(v,lo,hi) v=tonumber(v) or lo; if v<lo then return lo elseif v>hi then return hi end; return v end
local function upper(v) return tostring(v or ""):upper() end
local function nice(v)
    local s=tostring(v or ""):gsub("minecraft:",""):gsub("[_%-]"," "):gsub("(%l)(%u)","%1 %2")
    return upper(s)
end
local function gameTime()
    local ok,t=pcall(os.time,"ingame"); t=ok and tonumber(t) or 0
    local h=math.floor(t%24); local m=math.floor(((t%24)-h)*60)
    return string.format("%02d:%02d",h,m)
end
local function fmtNumber(v)
    local n=tonumber(v); if not n then return "?" end; local a=math.abs(n)
    if a>=1e15 then return string.format("%.1fP",n/1e15) elseif a>=1e12 then return string.format("%.1fT",n/1e12) elseif a>=1e9 then return string.format("%.1fG",n/1e9) elseif a>=1e6 then return string.format("%.1fM",n/1e6) elseif a>=1e3 then return string.format("%.1fK",n/1e3) end
    return math.abs(n-math.floor(n))>.01 and string.format("%.2f",n) or tostring(math.floor(n))
end
local function fmtFE(v,rate) local s=fmtNumber(v); return s=="?" and "?" or s.." FE"..(rate and "/t" or "") end

local glyphs={
 ["0"]={"111","101","101","101","111"}, ["1"]={"010","110","010","010","111"},
 ["2"]={"111","001","111","100","111"}, ["3"]={"111","001","111","001","111"},
 ["4"]={"101","101","111","001","001"}, ["5"]={"111","100","111","001","111"},
 ["6"]={"111","100","111","101","111"}, ["7"]={"111","001","010","010","010"},
 ["8"]={"111","101","111","101","111"}, ["9"]={"111","101","111","001","111"},
 [":"]={"0","1","0","1","0"}
}

function Adaptive.create(options)
    options=options or {}
    local mode=options.mode or "wall"
    local cfg,monitors,lastEnv,lastMeta=nil,{},nil,nil
    local targets,manual,pages,toasts={},{},{},{}
    local C={bg=colors.black,panel=colors.gray,panel2=colors.lightGray,text=colors.white,dim=colors.lightGray,good=colors.lime,warn=colors.orange,bad=colors.red,action=colors.blue,accent=colors.cyan or colors.lightBlue}

    local function stateOf(env) return env and env.state or {} end
    local function computerName()
        local label=type(os.getComputerLabel)=="function" and os.getComputerLabel() or nil
        if label and tostring(label):match("%S") and not tostring(label):match("^KIMI[%s%-]?%d+$") then return upper(label) end
        local n=cfg and cfg.name
        if n and tostring(n):match("%S") and not tostring(n):match("^KIMI[%s%-]?%d+$") then return upper(n) end
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
                        out[#out+1]={name=name,mon=mon,w=w,h=h,scale=scale,area=w*h}
                    end
                end
            end
        end
        table.sort(out,function(a,b) if a.area~=b.area then return a.area>b.area elseif a.w~=b.w then return a.w>b.w else return a.name<b.name end end)
        return out
    end

    local function prep(e)
        pcall(e.mon.setTextScale,e.scale); e.mon.setBackgroundColor(C.bg); e.mon.setTextColor(C.text); e.mon.clear(); e.mon.setCursorPos(1,1)
    end
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
    local function labelValue(e,x,y,label,value,valueColor)
        put(e,x,y,upper(label),C.dim); put(e,x,y+1,tostring(value or ""),valueColor or C.text)
    end
    local function register(e,t) targets[e.name]=targets[e.name] or {}; targets[e.name][#targets[e.name]+1]=t end
    local function button(e,name,x1,y1,x2,y2,text,enabled,data,bg,fg)
        enabled=enabled~=false; x1,x2=math.max(2,x1),math.min(e.w-1,x2); y1,y2=math.max(1,y1),math.min(e.h,y2); if x2<x1 or y2<y1 then return end
        bg=enabled and (bg or C.action) or C.panel; fg=enabled and (fg or C.text) or C.dim
        fill(e,x1,y1,x2,y2,bg); local px=math.max(1,math.min(3,math.floor((x2-x1)/6))); center(e,math.floor((y1+y2)/2),text,fg,bg,x1+px,x2-px)
        register(e,{name=name,x1=x1,y1=y1,x2=x2,y2=y2,enabled=enabled,data=data,label=text})
    end
    local function header(e,title,right)
        put(e,2,1,upper(title),C.text); if right then put(e,math.max(2,e.w-#tostring(right)-1),1,tostring(right),C.dim) end
        put(e,2,2,computerName(),C.dim); rule(e,3,1,e.w,C.panel)
    end
    local function statusChip(e,x1,x2,y,label,value,color)
        fill(e,x1,y,x2,y+2,C.panel); center(e,y,upper(label),C.dim,C.panel,x1+1,x2-1); center(e,y+1,upper(value),color or C.text,C.panel,x1+1,x2-1)
    end
    local function drawBar(e,x1,y,x2,p,color)
        local width=math.max(1,x2-x1+1); local n=math.floor(width*clamp(p or 0,0,100)/100+.5)
        if n>0 then fill(e,x1,y,x1+n-1,y,color) end; if n<width then fill(e,x1+n,y,x2,y,C.panel) end
    end
    local function bigClock(e,y,x1,x2)
        local value=gameTime(); x1,x2=x1 or 2,x2 or e.w-1
        if e.h<18 or x2-x1<30 then center(e,y,value,C.text,nil,x1,x2); return end
        local scale=(x2-x1+1)>=45 and 2 or 1; local gap=1; local total=0; local widths={}
        for i=1,#value do local ch=value:sub(i,i); widths[i]=(ch==":" and 1 or 3)*scale; total=total+widths[i]+(i<#value and gap or 0) end
        local x=x1+math.max(0,math.floor(((x2-x1+1)-total)/2))
        for i=1,#value do
            local ch=value:sub(i,i); local rows=glyphs[ch]; local cols=ch==":" and 1 or 3
            for r=1,5 do for c=1,cols do if rows[r]:sub(c,c)=="1" then fill(e,x+(c-1)*scale,y+r-1,x+c*scale-1,y+r-1,C.text) end end end
            x=x+widths[i]+gap
        end
    end

    local function localSource(meta) return meta and meta.localServer and "server" or tostring(os.getComputerID()) end
    local function sourceName(source,env)
        source=tostring(source or "server"); if source=="server" then return "MAIN BASE" end
        local s=stateOf(env); local item=(s.sources and s.sources[source]) or (s.fleet and (s.fleet[source] or s.fleet[tonumber(source)]))
        if item and item.name and not tostring(item.name):match("^KIMI[%s%-]?%d+$") then return upper(item.name) end
        if item and item.role=="node" then return "REMOTE NODE" end
        return "ROOM PANEL"
    end
    local function localDoors(env,meta)
        local out,seen={},{}; local ls=meta and meta.localState or {}
        for _,d in ipairs(ls.doors and ls.doors.localDoors or {}) do local k=tostring(d.key or tostring(d.target).."|"..tostring(d.side or "")); local c={}; for a,b in pairs(d) do c[a]=b end; c._source=localSource(meta); out[#out+1]=c; seen[k]=true end
        for _,d in ipairs(stateOf(env).doors and stateOf(env).doors.doors or {}) do if tostring(d._source or d.source or "server")==localSource(meta) then local k=tostring(d.key or tostring(d.target).."|"..tostring(d.side or "")); if not seen[k] then out[#out+1]=d; seen[k]=true end end end
        return out
    end
    local function localCandidates(meta)
        local ls=meta and meta.localState or {}; local dedicated,computer={},{}
        for _,c in ipairs(ls.doors and ls.doors.candidates or {}) do if c.localConfigured~=true then if tostring(c.target)=="computer" then computer[#computer+1]=c else dedicated[#dedicated+1]=c end end end
        return #dedicated>0 and dedicated or computer
    end
    local function attachmentsLocal(meta) local ls=meta and meta.localState or {}; return ls.attachments or {} end
    local function localSensors(meta) return attachmentsLocal(meta).sensors or {} end
    local function globalAttachments(env) return stateOf(env).attachments or {} end
    local function globalSensors(env) return globalAttachments(env).sensors or {} end

    local function sensorMetric(sensor)
        local m=sensor and sensor.metrics or {}; local order={{"temperature","TEMP"},{"radiationRaw","RADIATION"},{"radiationText","RADIATION"},{"onlinePlayers","PLAYERS"},{"biome","BIOME"},{"dimension","DIMENSION"},{"humidity","HUMIDITY"},{"pressure","PRESSURE"},{"maxScanRadius","RANGE"}}
        for _,p in ipairs(order) do if m[p[1]]~=nil then return p[2],nice(m[p[1]]) end end
        return "STATUS",upper(sensor and sensor.summary or "ONLINE")
    end
    local function sensorTitle(sensor)
        local t=nice(sensor and sensor.type or "SENSOR"); if t:find("ENVIRONMENT",1,true) then return "ENVIRONMENT" elseif t:find("PLAYER",1,true) then return "PLAYER DETECTOR" elseif t:find("GEO",1,true) then return "GEO SCANNER" elseif t:find("BLOCK",1,true) then return "BLOCK READER" end; return t
    end

    local function choosePower(raw)
        raw=raw or {}; local best,bestScore=nil,-1
        local function consider(p) if type(p)~="table" then return end; local cap=tonumber(p.capacity) or 0; local stored=tonumber(p.stored) or 0; local input=tonumber(p.input) or 0; local output=tonumber(p.output) or 0; local score=(cap>0 and 1e9 or 0)+(stored>0 and 1e7 or 0)+math.abs(input)+math.abs(output); if score>bestScore then best,bestScore=p,score end end
        for _,p in ipairs(raw.matrices or {}) do consider(p) end; for _,p in ipairs(raw.fluxNetworks or {}) do consider(p) end; for _,p in ipairs(raw.energyDetectors or {}) do consider(p) end; consider(raw); return best or raw
    end
    local function powerState(env,meta,localOnly) local raw=localOnly and meta and meta.localState and meta.localState.power or stateOf(env).power; raw=raw or {}; return raw,choosePower(raw) end
    local function percent(p) local n=tonumber(p and p.filledPercentage); if n then if n<=1 then n=n*100 end; return clamp(n,0,100) end; local st,cap=tonumber(p and p.stored),tonumber(p and p.capacity); if st and cap and cap>0 then return clamp(st/cap*100,0,100) end end

    local function fleetStats(env)
        local fleet=stateOf(env).fleet or {}; local total,online,current=0,0,0; local target=tostring(env and env.version or "")
        for _,m in pairs(fleet) do total=total+1; if m.online~=false then online=online+1 end; if m.online~=false and tostring(m.version or "")==target then current=current+1 end end
        return fleet,total,online,current,target
    end
    local function fleetLabel(env)
        local _,total,online,current=fleetStats(env)
        if total>0 and online==total and current==total then return "FLEET LOCKED "..current.."/"..total,C.good end
        if online<total then return "FLEET "..online.."/"..total.." ONLINE",C.warn end
        return "SYNCING "..current.."/"..total,C.warn
    end

    local function nav(e)
        if mode~="admin" or e.w<42 or e.h<15 then return end
        local items={{"nav_home","HOME"},{"nav_doors","DOORS"},{"nav_power","POWER"},{"nav_sensors","SENSORS"},{"nav_fleet","FLEET"}}
        local left,right,gap=2,e.w-1,1; local usable=right-left+1-gap*(#items-1); local cell=math.floor(usable/#items); local y=e.h-2
        for i,item in ipairs(items) do local x1=left+(i-1)*(cell+gap); local x2=i==#items and right or x1+cell-1; button(e,item[1],x1,y,x2,e.h,item[2],true,nil,C.panel,C.text) end
    end

    local function sensorLink(meta)
        local a=attachmentsLocal(meta); local sensors=a.sensors or {}; local diag=a.diagnostics or {}
        if #sensors>0 then return true,tostring(#sensors).." LINKED",C.good end
        if diag.onlyInfrastructure then return false,"NOT CONNECTED",C.warn end
        if tonumber(a.dataCount or 0)>0 then return false,"UNKNOWN DEVICE",C.warn end
        return false,"NO LINK",C.warn
    end
    local function drawRoomSensor(e,meta,y)
        local linked,text,color=sensorLink(meta); local a=attachmentsLocal(meta); rule(e,y,2,e.w-1); y=y+1
        put(e,2,y,"SENSOR LINK",C.dim); put(e,14,y,text,color)
        if linked then
            local s=(a.sensors or {})[1]; local k,v=sensorMetric(s); put(e,2,y+1,sensorTitle(s),C.text); put(e,2,y+2,k.."  "..v,C.good)
        else
            local diag=a.diagnostics or {}
            if diag.onlyInfrastructure then
                put(e,2,y+1,"WIRE DETECTOR TO THIS COMPUTER",C.warn)
                put(e,2,y+2,"OR USE A WIRED MODEM",C.warn)
            else
                local msg=tostring(diag.hint or "NO SENSOR TELEMETRY"); put(e,2,y+1,msg:sub(1,e.w-3),C.warn)
            end
        end
    end

    local function groupCandidates(list)
        local order,groups={},{}
        for _,c in ipairs(list or {}) do local k=tostring(c.target); if not groups[k] then groups[k]={}; order[#order+1]=k end; groups[k][#groups[k]+1]=c end
        table.sort(order,function(a,b) local ga,gb=groups[a][1],groups[b][1]; local pa=ga and ga.priority or 5; local pb=gb and gb.priority or 5; if pa~=pb then return pa<pb end; return a<b end)
        return order,groups
    end

    local function renderRoom(e,env,meta)
        prep(e); header(e,"ROOM",gameTime()); local doors=localDoors(env,meta); local linked,sensorText,sensorColor=sensorLink(meta)
        statusChip(e,2,math.floor(e.w/2)-1,5,"BASE",meta and meta.connected==false and "OFFLINE" or "ONLINE",meta and meta.connected==false and C.warn or C.good)
        statusChip(e,math.floor(e.w/2)+1,e.w-1,5,"SENSOR",sensorText,sensorColor)

        if #doors>0 then
            local d=doors[1]; local dmode=tostring(d.mode or "hold"); local isPulse=dmode=="pulse"; local state=d.online==false and "OFFLINE" or (isPulse and "PULSE MODE" or (d.open and "OPEN" or "CLOSED"))
            center(e,9,upper(d.name or "DOOR"),C.text,nil,2,e.w-1); center(e,11,state,d.online==false and C.bad or (d.open and C.good or C.text),nil,2,e.w-1)
            local actionText=isPulse and "TRIGGER DOOR" or (d.open and "CLOSE DOOR" or "OPEN DOOR")
            button(e,"door_toggle_local",3,13,e.w-2,math.max(17,e.h-8),actionText,d.online~=false,{_source=localSource(meta),target=d.target,side=d.side,id=d.id},d.open and C.good or C.action,d.open and colors.black or C.text)
            local modeY=e.h-6
            if d.supportsModes~=false then button(e,"door_mode",3,modeY,math.floor(e.w*.55),modeY+1,"MODE  "..upper(dmode),true,{target=d.target,side=d.side,mode=dmode},C.panel,C.text) end
            drawRoomSensor(e,meta,e.h-4)
            return
        end

        local candidates=localCandidates(meta)
        center(e,10,"SET UP DOOR",C.text,nil,2,e.w-1)
        if #candidates==0 then
            center(e,12,"NO DOOR ACTUATOR FOUND",C.warn,nil,2,e.w-1); center(e,14,"CONNECT REDSTONE / RELAY / DOOR CONTROLLER",C.dim,nil,2,e.w-1); drawRoomSensor(e,meta,e.h-4); return
        end
        local order,groups=groupCandidates(candidates); local key=e.name..":controller"; pages[key]=clamp(pages[key] or 1,1,#order); local list=groups[order[pages[key]]] or {}; local first=list[1]
        center(e,12,first and nice(first.type or first.controller) or "CONTROLLER",C.dim,nil,2,e.w-1)
        if first and #list==1 and not first.side then
            button(e,"door_register_local",3,14,e.w-2,18,"USE THIS ACTUATOR",true,{target=first.target,side=first.side,name=computerName()},C.action)
        else
            center(e,14,"WHICH OUTPUT OPENS THE DOOR?",C.dim,nil,2,e.w-1)
            local left,right,gap=3,e.w-2,1; local cell=math.floor((right-left+1-gap*2)/3); local top=16
            for i,c in ipairs(list) do if i>6 then break end; local col=(i-1)%3; local row=math.floor((i-1)/3); local x1=left+col*(cell+gap); local x2=col==2 and right or x1+cell-1; local y1=top+row*3; button(e,"door_register_local",x1,y1,x2,y1+1,nice(c.side or c.label or "OUTPUT"),true,{target=c.target,side=c.side,name=computerName()},C.action) end
        end
        if #order>1 then button(e,"setup_next",3,e.h-7,e.w-2,e.h-6,"OTHER CONTROLLER",true,{key=key,count=#order},C.panel,C.text) end
        drawRoomSensor(e,meta,e.h-4)
    end

    local function renderOverview(e,env,meta)
        prep(e); header(e,"COMMAND CENTER",gameTime()); local s=stateOf(env); local _,total,online,current=fleetStats(env); local sensors=globalSensors(env); local doors=s.doors and s.doors.doors or {}; local raw,pwr=powerState(env,meta,false); local p=percent(pwr)
        local chipGap=1; local left=2; local totalWidth=e.w-2; local chip=math.floor((totalWidth-chipGap*3)/4)
        statusChip(e,left,left+chip-1,5,"FLEET",online.."/"..total,online==total and C.good or C.warn)
        statusChip(e,left+chip+chipGap,left+chip*2+chipGap-1,5,"DOORS",tostring(#doors),#doors>0 and C.good or C.dim)
        statusChip(e,left+chip*2+chipGap*2,left+chip*3+chipGap*2-1,5,"SENSORS",tostring(#sensors),#sensors>0 and C.good or C.warn)
        statusChip(e,left+chip*3+chipGap*3,e.w-1,5,"POWER",p and string.format("%.0f%%",p) or "N/A",p and C.good or C.dim)
        local split=math.floor(e.w*.54)
        put(e,2,10,"BASE TIME",C.dim); bigClock(e,12,2,split-2)
        put(e,split+1,10,"POWER",C.dim); if p then put(e,split+1,12,string.format("%.1f%%",p),p>=50 and C.good or C.warn); drawBar(e,split+1,14,e.w-2,p,p>=50 and C.good or C.warn); put(e,split+1,16,"IN  +"..fmtFE(pwr.input,true),C.good); put(e,split+1,17,"OUT -"..fmtFE(pwr.output,true),C.warn); put(e,split+1,19,"STORED "..fmtFE(pwr.stored,false),C.text) else put(e,split+1,12,"NO POWER DATA",C.dim) end
        rule(e,e.h-6,2,e.w-1); local fl,fc=fleetLabel(env); put(e,2,e.h-5,fl,fc)
        if #sensors==0 then put(e,2,e.h-4,"SENSOR BUS  NO DETECTOR TELEMETRY",C.warn) elseif #doors==0 then put(e,2,e.h-4,"DOORS  NONE CONFIGURED",C.dim) else put(e,2,e.h-4,"SYSTEMS  NOMINAL",C.good) end
        nav(e)
    end

    local function renderPower(e,env,meta,localOnly)
        prep(e); header(e,localOnly and "LOCAL POWER" or "POWER",gameTime()); local raw,pwr=powerState(env,meta,localOnly); local sources=tonumber(raw.onlineSources) or 0; local p=percent(pwr)
        if sources<=0 then center(e,math.floor(e.h/2),"NO POWER TELEMETRY",C.dim,nil,2,e.w-1); nav(e); return end
        center(e,6,p and string.format("%.1f%%",p) or "POWER ONLINE",p and C.good or C.text,nil,2,e.w-1); if p then drawBar(e,3,8,e.w-2,p,p>=50 and C.good or C.warn) end
        labelValue(e,2,11,"STORED",fmtFE(pwr.stored,false)); labelValue(e,math.floor(e.w/2),11,"CAPACITY",fmtFE(pwr.capacity,false))
        labelValue(e,2,15,"INPUT","+ "..fmtFE(pwr.input,true),C.good); labelValue(e,math.floor(e.w/2),15,"OUTPUT","- "..fmtFE(pwr.output,true),C.warn)
        rule(e,19); labelValue(e,2,21,"SOURCES",sources,C.text)
        local y=24; for i,m in ipairs(raw.matrices or {}) do if y>e.h-4 then break end; put(e,2,y,"MATRIX "..i,C.dim); put(e,2,y+1,(percent(m) and string.format("%.1f%%",percent(m)) or "ONLINE").."  "..fmtFE(m.stored,false),C.good); y=y+3 end
        nav(e)
    end

    local function renderSensors(e,env,meta,localOnly)
        prep(e); header(e,localOnly and "LOCAL SENSORS" or "SENSORS",gameTime()); local a=localOnly and attachmentsLocal(meta) or globalAttachments(env); local sensors=a.sensors or {}; local devices=a.devices or {}; local diag=a.diagnostics or {}
        if #sensors==0 then
            center(e,6,"SENSOR LINK OFFLINE",C.warn,nil,2,e.w-1)
            if diag.onlyInfrastructure then
                center(e,9,"ONLY MONITOR / MODEM INFRASTRUCTURE IS VISIBLE",C.text,nil,2,e.w-1); center(e,11,"THE DETECTOR IS NOT ON THE PERIPHERAL BUS",C.warn,nil,2,e.w-1); center(e,14,"FIX",C.dim,nil,2,e.w-1); center(e,16,"PLACE DETECTOR NEXT TO THE COMPUTER",C.text,nil,2,e.w-1); center(e,17,"OR ATTACH A WIRED MODEM TO IT",C.text,nil,2,e.w-1)
            elseif tonumber(a.dataCount or 0)>0 then
                center(e,9,"UNKNOWN DATA PERIPHERAL FOUND",C.warn,nil,2,e.w-1); put(e,3,12,tostring(diag.hint or "UNKNOWN SENSOR API"):sub(1,e.w-5),C.text)
            else
                center(e,10,"NO DETECTOR PERIPHERAL IS VISIBLE",C.dim,nil,2,e.w-1)
            end
            put(e,2,e.h-5,"VISIBLE PERIPHERALS  "..tostring(#devices),C.dim); nav(e); return
        end
        local cols=e.w>=46 and 2 or 1; local colW=math.floor((e.w-3)/cols); local y0=6
        for i,sensor in ipairs(sensors) do
            local col=(i-1)%cols; local row=math.floor((i-1)/cols); local x=2+col*(colW+1); local y=y0+row*6; if y>e.h-6 then break end
            put(e,x,y,sensorTitle(sensor),C.text); put(e,x,y+1,localOnly and "LOCAL" or sourceName(sensor._source,env),C.dim); local k,v=sensorMetric(sensor); put(e,x,y+3,k,C.dim); put(e,x,y+4,v,C.good)
        end
        nav(e)
    end

    local function renderFleet(e,env)
        prep(e); header(e,"FLEET",gameTime()); local fleet,total,online,current,target=fleetStats(env); local fl,fc=fleetLabel(env); center(e,5,fl,fc,nil,2,e.w-1); put(e,2,7,"TARGET  "..target,C.dim); rule(e,9)
        local ids={}; for id in pairs(fleet) do ids[#ids+1]=id end; table.sort(ids,function(a,b)return tonumber(a or 0)<tonumber(b or 0)end)
        local y=11
        for _,id in ipairs(ids) do if y>e.h-5 then break end; local m=fleet[id]; local display=m.name; if not display or tostring(display):match("^KIMI[%s%-]?%d+$") then display=m.role=="server" and "MAIN BASE" or (m.role=="node" and "REMOTE NODE" or "ROOM PANEL") end
            local good=m.online~=false and tostring(m.version or "")==target; put(e,2,y,upper(display),good and C.good or C.warn); put(e,2,y+1,upper(tostring(m.version or "UNKNOWN")),C.text); put(e,2,y+2,m.online==false and "OFFLINE" or (good and "CURRENT" or "UPDATING"),good and C.good or C.warn); y=y+4 end
        nav(e)
    end

    local function renderDoors(e,env)
        prep(e); header(e,"DOORS",gameTime()); local list=stateOf(env).doors and stateOf(env).doors.doors or {}
        if #list==0 then center(e,math.floor(e.h/2)-1,"NO DOORS REGISTERED",C.dim,nil,2,e.w-1); center(e,math.floor(e.h/2)+1,"SET UP EACH DOOR ON ITS ROOM PANEL",C.good,nil,2,e.w-1); nav(e); return end
        local cols=e.w>=45 and 2 or 1; local gap=1; local cellW=math.floor((e.w-3-gap*(cols-1))/cols); local y=6
        for i,d in ipairs(list) do local col=(i-1)%cols; local row=math.floor((i-1)/cols); local x=2+col*(cellW+gap); local yy=y+row*6; if yy>e.h-6 then break end; fill(e,x,yy,x+cellW-1,yy+4,C.panel); center(e,yy+1,upper(d.name or sourceName(d._source,env)),C.text,C.panel,x+1,x+cellW-2); center(e,yy+3,d.online==false and "OFFLINE" or (d.open and "OPEN" or "CLOSED"),d.online==false and C.bad or (d.open and C.good or C.dim),C.panel,x+1,x+cellW-2) end
        nav(e)
    end

    local function renderStatus(e,env,meta)
        prep(e); header(e,"BASE STATUS",gameTime()); bigClock(e,6,2,e.w-1); local fl,fc=fleetLabel(env); center(e,13,fl,fc,nil,2,e.w-1); local linked,text,color=sensorLink(meta); center(e,15,"SENSOR "..text,color,nil,2,e.w-1)
    end

    local renderers={overview=renderOverview,room=renderRoom,status=renderStatus,power=function(e,env,meta)renderPower(e,env,meta,false)end,power_local=function(e,env,meta)renderPower(e,env,meta,true)end,sensors=function(e,env,meta)renderSensors(e,env,meta,false)end,sensors_local=function(e,env,meta)renderSensors(e,env,meta,true)end,fleet=renderFleet,doors=renderDoors}

    local function autoViews(env,meta)
        local views={}
        if mode=="admin" then
            views[#views+1]="overview"; local s=stateOf(env); if tonumber(s.power and s.power.onlineSources or 0)>0 then views[#views+1]="power" end; views[#views+1]="fleet"; if #globalSensors(env)>0 then views[#views+1]="sensors" end; if #(s.doors and s.doors.doors or {})>0 then views[#views+1]="doors" end
        else
            views[#views+1]="room"; if #localSensors(meta)>0 then views[#views+1]="sensors_local" end; views[#views+1]="status"
        end
        return views
    end
    local function plan(env,meta)
        local available=autoViews(env,meta); local out={}
        for i,e in ipairs(monitors) do out[e.name]=manual[e.name] or available[((i-1)%#available)+1] end
        return out
    end
    local function renderOne(e,view,env,meta) targets[e.name]={}; (renderers[view] or renderStatus)(e,env,meta or {}) end
    local function redraw(name)
        if not lastEnv then return end; local assigned=plan(lastEnv,lastMeta or {}); for _,e in ipairs(monitors) do if e.name==name then renderOne(e,manual[name] or assigned[name],lastEnv,lastMeta or {}); return end end
    end

    local M={}
    function M.init(newCfg) cfg=newCfg or {}; monitors=detectMonitors(); term.clear(); term.setCursorPos(1,1); print("KIMI Adaptive Display v7"); print("monitors: "..#monitors) end
    function M.render(env,meta) monitors=detectMonitors(); lastEnv,lastMeta=env,meta or {}; targets={}; local assigned=plan(env,lastMeta); for _,e in ipairs(monitors) do renderOne(e,assigned[e.name],env,lastMeta) end end
    function M.onPeripheralChange() monitors=detectMonitors(); targets={} end
    function M.handleEvent(event,env,action)
        if type(event)~="table" or event[1]~="monitor_touch" then return end
        local name,x,y=event[2],tonumber(event[3]),tonumber(event[4]); if not x or not y then return end
        for _,t in ipairs(targets[name] or {}) do
            if t.enabled and x>=t.x1 and x<=t.x2 and y>=t.y1 and y<=t.y2 then
                local entry; for _,e in ipairs(monitors) do if e.name==name then entry=e; break end end
                if entry then fill(entry,t.x1,t.y1,t.x2,t.y2,colors.white); center(entry,math.floor((t.y1+t.y2)/2),t.label or "OK",colors.black,colors.white,t.x1+2,t.x2-2) end
                local n=t.name
                if n=="nav_home" then manual[name]="overview"
                elseif n=="nav_doors" then manual[name]="doors"
                elseif n=="nav_power" then manual[name]="power"
                elseif n=="nav_sensors" then manual[name]="sensors"
                elseif n=="nav_fleet" then manual[name]="fleet"
                elseif n=="setup_next" and t.data then pages[t.data.key]=((pages[t.data.key] or 1)%t.data.count)+1
                elseif n=="door_register_local" and t.data then local ok,res=action and action("__local_doors","register_local",t.data); if ok~=false then manual[name]="room" else toasts[name]=tostring(res or "SETUP FAILED") end
                elseif n=="door_toggle_local" and t.data then if action then action("__local_doors","toggle",t.data) end
                elseif n=="door_mode" and t.data then
                    local nextMode=t.data.mode=="hold" and "invert" or (t.data.mode=="invert" and "pulse" or "hold")
                    if action then action("__local_doors","configure_local",{target=t.data.target,side=t.data.side,mode=nextMode}) end
                end
                redraw(name); return true
            end
        end
    end
    return M
end

return Adaptive
