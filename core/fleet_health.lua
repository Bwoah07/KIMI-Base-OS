local M={}

-- Fleet presence is deliberately much calmer than control-path liveness.
-- Normal clients heartbeat roughly every two seconds, but a fixed base computer
-- may stop ticking entirely while its Minecraft chunk is unloaded. Treat that
-- as sleeping infrastructure, not as a dead/reappearing machine every few
-- minutes. Door/control transports keep their own fast ACK timeouts.
M.ONLINE_MS=120000
M.OFFLINE_MS=1800000

local function sameId(a,b)
    if a==nil or b==nil then return false end
    return tostring(a)==tostring(b)
end

function M.age(machine,now)
    machine=type(machine)=="table" and machine or {}
    local cached=tonumber(machine.ageMs)
    local seen=tonumber(machine.lastSeen)
    now=tonumber(now)
    if now and seen then return math.max(0,now-seen) end
    if cached then return math.max(0,cached) end
    return math.huge
end

function M.status(id,machine,serverId,now)
    if sameId(id,serverId) then return "ONLINE",0 end
    local age=M.age(machine,now)
    if age<=M.ONLINE_MS then return "ONLINE",age end
    if age<=M.OFFLINE_MS then return "STALE",age end
    return "OFFLINE",age
end

function M.ageText(age)
    age=tonumber(age)
    if not age or age==math.huge then return "NEVER" end
    if age<1000 then return "NOW" end
    local s=math.floor(age/1000+.5)
    if s<60 then return tostring(s).."s" end
    local m=math.floor(s/60)
    if m<60 then return tostring(m).."m" end
    local h=math.floor(m/60)
    return tostring(h).."h"
end

return M
