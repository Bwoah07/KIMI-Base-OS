local M={}

-- Hardware scans are intentionally slower than the two-second fleet heartbeat.
-- Keep connection truth and data freshness separate so a reachable computer is
-- never described as offline merely because AE2/Flux/Builder took longer to
-- sample. Cached samples remain visible (and clearly labelled) through normal
-- chunk sleep, but are never eligible for remote control.
M.LIVE_MS=20000
M.CACHED_MS=1800000

local function age(source,now)
    source=type(source)=="table"and source or{}
    local seen=tonumber(source.lastTelemetry)or tonumber(source.lastSeen)
    local cached=tonumber(source.telemetryAgeMs)
    now=tonumber(now)
    if now and seen then return math.max(0,now-seen)end
    if cached then return math.max(0,cached)end
    return math.huge
end

function M.status(source,presence,now)
    source=type(source)=="table"and source or{}
    local sampleAge=age(source,now)
    local hasState=type(source.state)=="table"and next(source.state)~=nil
    if not hasState then return "MISSING",sampleAge end
    presence=tostring(presence or source.presence or""):upper()
    if sampleAge<=M.LIVE_MS and (presence=="ONLINE"or presence=="LATE")then
        return "LIVE",sampleAge
    end
    if sampleAge<=M.CACHED_MS then return "CACHED",sampleAge end
    return "EXPIRED",sampleAge
end

function M.usable(status)
    status=tostring(status or""):upper()
    return status=="LIVE"or status=="CACHED"
end

function M.rank(status)
    status=tostring(status or""):upper()
    if status=="LIVE"then return 3 end
    if status=="CACHED"then return 2 end
    if status=="MISSING"then return 1 end
    return 0
end

function M.age(source,now)return age(source,now)end

return M
