local health=require("core.fleet_health")
local M={}

M.PROOF_MS=15000
M.GHOST_MS=600000
M.FORGET_MS=86400000

local function sameId(a,b)
    if a==nil or b==nil then return false end
    return tostring(a)==tostring(b)
end

function M.proofAge(machine,now)
    machine=type(machine)=="table"and machine or{}
    local verified=tonumber(machine.verifiedAt)
    now=tonumber(now)
    if verified and now then return math.max(0,now-verified)end
    return math.huge
end

function M.status(id,machine,serverId,now)
    if sameId(id,serverId)then return"ONLINE",0,true end
    local base,age=health.status(id,machine,serverId,now)
    local proof=M.proofAge(machine,now)
    local verified=proof<=M.PROOF_MS
    if base=="ONLINE"and not verified then return"VERIFY",age,false end
    if base=="OFFLINE"and age>M.GHOST_MS then return"GHOST",age,false end
    return base,age,verified
end

function M.versionText(machine,verified)
    machine=type(machine)=="table"and machine or{}
    local version=tostring(machine.version or"?")
    return(verified and"LIVE "or"LAST ")..version
end

function M.shouldForget(machine,now)
    machine=type(machine)=="table"and machine or{}
    local seen=tonumber(machine.lastSeen)
    now=tonumber(now)
    return seen~=nil and now~=nil and now-seen>M.FORGET_MS
end

return M
