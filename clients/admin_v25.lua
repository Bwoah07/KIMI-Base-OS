-- Alpha74 fleet sanity overlay.
-- The alpha73 fleet screen independently re-derived heartbeat state and could
-- literally mark the computer rendering Main Base as OFFLINE. Keep the proven
-- alpha73 monitor planner/identify targets, then repaint only the fleet rows
-- from one shared health policy with a generous cosmetic grace window.
local base=require("clients.admin_v24")
local health=require("core.fleet_health")
local M={}
for k,v in pairs(base)do M[k]=v end

local C={bg=colors.black,text=colors.white,dim=colors.lightGray,good=colors.lime,warn=colors.orange,bad=colors.red}

local function upper(v)return tostring(v or""):upper()end
local function safeNow()
    if type(os.epoch)=="function" then
        local ok,v=pcall(os.epoch,"utc")
        if ok and tonumber(v) then return tonumber(v) end
    end
    local ok,t=pcall(os.time,"ingame")
    return math.floor((ok and tonumber(t) or 0)*1000)
end
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
local function put(e,x,y,text,fg)
    if not e or y<1 or y>e.h or x>e.w then return end
    text=tostring(text or"");e.mon.setCursorPos(math.max(1,x),y);e.mon.setBackgroundColor(C.bg);e.mon.setTextColor(fg or C.text);e.mon.write(text:sub(1,math.max(0,e.w-x+1)))
end
local function clearRow(e,y)
    if y<1 or y>e.h then return end
    put(e,1,y,string.rep(" ",e.w),C.text)
end

local function overlayFleet(e,env)
    if not e then return end
    local state=env and env.state or{};local fleet=state.fleet or{};local serverId=env and env.serverId
    local ids={};for id in pairs(fleet)do ids[#ids+1]=id end
    table.sort(ids,function(a,b)local na,nb=tonumber(a),tonumber(b);if na and nb then return na<nb end;return tostring(a)<tostring(b)end)

    local now=safeNow();local y=8
    for _,id in ipairs(ids)do
        if y+1>e.h then break end
        local machine=fleet[id] or{};local status,age=health.status(id,machine,serverId,now)
        local fg=status=="ONLINE"and C.good or(status=="STALE"and C.warn or C.bad)
        clearRow(e,y);clearRow(e,y+1)
        local label="ID "..tostring(id).." "..upper(machine.name or machine.role or"KIMI")
        put(e,2,y,label,C.text);put(e,math.max(2,e.w-#status-1),y,status,fg)
        local role=upper(machine.role or"?");local version=tostring(machine.version or"?")
        local suffix=tostring(id)==tostring(serverId)and"LOCAL"or("SEEN "..health.ageText(age))
        local line=role.."  "..version
        put(e,2,y+1,line,C.dim)
        if #suffix+2<e.w then put(e,math.max(2,e.w-#suffix-1),y+1,suffix,C.dim)end
        y=y+3
    end
end

function M.render(env,meta)
    local ok=base.render(env,meta)
    local ms=monitors();if ms[3]then overlayFleet(ms[3],env)end
    return ok
end

return M
