local M={}

-- Alpha80's calm-presence window is retained for historical/remembered fleet
-- semantics. It must NOT be used to claim that a computer is reachable now.
M.ONLINE_MS=120000
M.OFFLINE_MS=1800000

-- Operational reachability is based on the dedicated alpha78 heartbeat, which
-- is emitted roughly every two seconds before heavy peripheral work. A green
-- ONLINE label therefore means Main Base has genuinely heard from that runtime
-- very recently, not merely that the machine existed a minute ago.
M.HEARTBEAT_MS=2000
M.REACHABLE_MS=6500
M.LATE_MS=15000

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

-- Historical/calm status retained for compatibility with alpha80 history.
function M.status(id,machine,serverId,now)
    if sameId(id,serverId) then return "ONLINE",0 end
    local age=M.age(machine,now)
    if age<=M.ONLINE_MS then return "ONLINE",age end
    if age<=M.OFFLINE_MS then return "STALE",age end
    return "OFFLINE",age
end

-- Current operational truth. Use this for dashboards, command eligibility and
-- telemetry source selection. Remembered machines remain in the registry, but
-- they are never painted green after their heartbeat stops.
function M.reachability(id,machine,serverId,now)
    if sameId(id,serverId) then return "ONLINE",0 end
    local age=M.age(machine,now)
    if age<=M.REACHABLE_MS then return "ONLINE",age end
    if age<=M.LATE_MS then return "LATE",age end
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
