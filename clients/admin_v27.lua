-- Alpha77 operational fleet screen.
-- Heartbeat age is the source of truth for the working list. Historical entries
-- are hidden instead of screaming VERIFY/GHOST at the operator.
local base=require("clients.admin_v26")
local health=require("core.fleet_health")
local M={}
for k,v in pairs(base)do M[k]=v end

local C={bg=colors.black,text=colors.white,dim=colors.lightGray,good=colors.lime,warn=colors.orange,bad=colors.red,panel=colors.gray,accent=colors.cyan or colors.lightBlue}
local lastEnv,lastMeta
local targets={}
local lastRequest=nil
local localMessage=""

local function upper(v)return tostring(v or""):upper()end
local function safeNow()
    if type(os.epoch)=="function"then local ok,v=pcall(os.epoch,"utc");if ok and tonumber(v)then return tonumber(v)end end
    local ok,t=pcall(os.time,"ingame");return math.floor((ok and tonumber(t)or 0)*1000)
end
local function gameTime()local ok,t=pcall(os.time,"ingame");t=ok and tonumber(t)or 0;local h=math.floor(t%24);local m=math.floor(((t%24)-h)*60+.5)%60;return string.format("%02d:%02d",h,m)end
local function sameId(a,b)return a~=nil and b~=nil and tostring(a)==tostring(b)end
local function isMonitor(n)
    local ok,t=pcall(peripheral.getType,n);if ok and t=="monitor"then return true end
    if type(peripheral.hasType)=="function"then local ok2,v=pcall(peripheral.hasType,n,"monitor");if ok2 and v then return true end end
    return false
end
local function monitors()
    local out={};local ok,names=pcall(peripheral.getNames);if not ok or type(names)~="table"then return out end
    for _,n in ipairs(names)do if isMonitor(n)then
        local okw,m=pcall(peripheral.wrap,n);if okw and m then
            local scale=1;pcall(m.setTextScale,scale);local oks,w,h=pcall(m.getSize)
            if oks then
                w,h=tonumber(w),tonumber(h)
                if w<22 or h<12 then scale=.5;pcall(m.setTextScale,scale);local ok2,w2,h2=pcall(m.getSize);if ok2 then w,h=tonumber(w2)or w,tonumber(h2)or h end end
                out[#out+1]={name=n,mon=m,w=w,h=h,area=w*h,scale=scale}
            end
        end
    end end
    table.sort(out,function(a,b)if a.area~=b.area then return a.area>b.area end;if a.w~=b.w then return a.w>b.w end;return a.name<b.name end)
    return out
end
local function put(e,x,y,text,fg,bg)
    if not e or y<1 or y>e.h or x>e.w then return end
    x=math.max(1,x);text=tostring(text or"")
    e.mon.setCursorPos(x,y);e.mon.setBackgroundColor(bg or C.bg);e.mon.setTextColor(fg or C.text)
    e.mon.write(text:sub(1,math.max(0,e.w-x+1)));e.mon.setBackgroundColor(C.bg)
end
local function prep(e)pcall(e.mon.setTextScale,e.scale);e.mon.setBackgroundColor(C.bg);e.mon.setTextColor(C.text);e.mon.clear()end
local function rule(e,y)put(e,2,y,string.rep("-",math.max(0,e.w-2)),C.panel)end
local function header(e)
    put(e,2,1,"FLEET / IDENTIFY",C.text);put(e,math.max(2,e.w-6),1,gameTime(),C.dim)
    local label=(type(os.getComputerLabel)=="function"and os.getComputerLabel())or"MAIN BASE";put(e,2,2,upper(label),C.dim);rule(e,3)
end

local function entries(env)
    local st=env and env.state or{};local fleet=st.fleet or{};local serverId=env and env.serverId;local now=safeNow()
    local out={};local live,stale,hidden=0,0,0
    for id,m in pairs(fleet)do
        local status,age=health.status(id,m,serverId,now)
        if sameId(id,serverId)or status=="ONLINE"or status=="STALE"then
            local shown=sameId(id,serverId)and"MAIN"or(status=="ONLINE"and"LIVE"or"STALE")
            if shown=="MAIN"or shown=="LIVE"then live=live+1 else stale=stale+1 end
            out[#out+1]={id=id,m=m or{},age=age,status=shown,localMachine=sameId(id,serverId)}
        else hidden=hidden+1 end
    end
    table.sort(out,function(a,b)
        local function rank(x)if x.localMachine then return 0 elseif x.status=="LIVE"then return 1 else return 2 end end
        local ra,rb=rank(a),rank(b);if ra~=rb then return ra<rb end
        local na,nb=upper(a.m.name or a.m.role or a.id),upper(b.m.name or b.m.role or b.id);if na~=nb then return na<nb end
        return tostring(a.id)<tostring(b.id)
    end)
    return out,live,stale,hidden,now
end

local function feedback(now)
    if localMessage~=""then return localMessage,C.warn end
    if not lastRequest then return"TOUCH A LIVE ROW -> FLASH THAT COMPUTER",C.dim end
    local acks=rawget(_G,"kimiIdentifyAck")or{};local ack=acks[tostring(lastRequest.id)]
    if type(ack)=="table"and tonumber(ack.at)and tonumber(ack.at)>=lastRequest.at then
        return"CONFIRMED ID "..tostring(lastRequest.id).." FLASHING",C.good
    end
    local age=now-lastRequest.at
    if age<3000 then return"WAITING FOR ID "..tostring(lastRequest.id).." ACK...",C.warn end
    return"ID "..tostring(lastRequest.id).." NOT REACHABLE",C.bad
end

local function renderFleet(e,env)
    prep(e);targets[e.name]={};header(e)
    local list,live,stale,hidden,now=entries(env)
    local summary="LIVE "..tostring(live).."  STALE "..tostring(stale)
    if hidden>0 then summary=summary.."  HIDDEN "..tostring(hidden)end
    put(e,2,5,summary,stale>0 and C.warn or C.good)
    local msg,fg=feedback(now);put(e,2,6,msg,fg);rule(e,7)
    local y=9
    for _,row in ipairs(list)do
        if y+1>e.h then break end
        local id,m,status=row.id,row.m,row.status
        local name=upper(m.name or m.role or("KIMI-"..tostring(id)))
        local tag=status
        put(e,2,y,"ID "..tostring(id).." "..name,C.text)
        put(e,math.max(2,e.w-#tag-1),y,tag,status=="STALE"and C.warn or C.good)
        local role=upper(m.role or"?");local version=tostring(m.version or"?")
        put(e,2,y+1,role.."  "..version,C.dim)
        local seen=row.localMachine and"LOCAL"or("SEEN "..health.ageText(row.age))
        if #seen+2<e.w then put(e,math.max(2,e.w-#seen-1),y+1,seen,C.dim)end
        targets[e.name][#targets[e.name]+1]={y1=y,y2=y+1,id=tonumber(id)or id,localMachine=row.localMachine}
        y=y+3
    end
    if #list==0 then put(e,2,10,"NO LIVE FLEET MEMBERS",C.warn)end
end

function M.init(c)
    targets={};lastRequest=nil;localMessage="";lastEnv,lastMeta=nil,nil
    return base.init and base.init(c)
end

function M.render(env,meta)
    lastEnv,lastMeta=env,meta
    local ok=base.render(env,meta)
    local ms=monitors();if ms[3]then renderFleet(ms[3],env)end
    return ok
end

function M.onPeripheralChange(...)
    targets={}
    if base.onPeripheralChange then return base.onPeripheralChange(...)end
end

function M.handleEvent(ev,env,action)
    lastEnv=env or lastEnv
    if ev[1]=="monitor_touch"then
        local ms=monitors();local fleetMon=ms[3];local name,y=ev[2],tonumber(ev[4])
        if fleetMon and name==fleetMon.name then
            localMessage=""
            for _,t in ipairs(targets[name]or{})do
                if y and y>=t.y1 and y<=t.y2 then
                    if t.localMachine then
                        lastRequest=nil;localMessage="THAT IS MAIN BASE - YOU ARE LOOKING AT IT"
                    else
                        local now=safeNow();local ok,res=pcall(action,"server","identify",{id=t.id,duration=10})
                        local sent=ok and type(res)=="table"and res.ok~=false
                        if sent then lastRequest={id=t.id,at=now};localMessage=""
                        else lastRequest=nil;localMessage="IDENTIFY SEND FAILED -> ID "..tostring(t.id)end
                    end
                    M.render(lastEnv,lastMeta);return true
                end
            end
            -- Swallow blank touches on the fleet monitor so the old alpha73
            -- hidden-row target map cannot accidentally identify a ghost entry.
            return true
        end
    end
    local handled=base.handleEvent and base.handleEvent(ev,env,action)or false
    return handled
end

return M
