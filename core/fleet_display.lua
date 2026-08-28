local M={}

local function sameId(a,b)
    return a~=nil and b~=nil and tostring(a)==tostring(b)
end

local function numericOrHuge(v)
    return tonumber(v) or math.huge
end

function M.rows(fleet,serverId)
    local rows={}
    for transportId,m in pairs(fleet or {}) do
        rows[#rows+1]={transportId=transportId,id=transportId,m=m or {},main=sameId(transportId,serverId)}
    end
    table.sort(rows,function(a,b)
        if a.main~=b.main then return a.main end
        local af,bf=numericOrHuge(a.m.firstSeen),numericOrHuge(b.m.firstSeen)
        if af~=bf then return af<bf end
        local ai,bi=tonumber(a.transportId),tonumber(b.transportId)
        if ai and bi and ai~=bi then return ai<bi end
        local an=tostring(a.m.name or a.m.role or a.transportId)
        local bn=tostring(b.m.name or b.m.role or b.transportId)
        if an~=bn then return an<bn end
        return tostring(a.transportId)<tostring(b.transportId)
    end)
    local nextId=2
    for _,row in ipairs(rows) do
        if row.main then row.displayId=1
        else row.displayId=nextId;nextId=nextId+1 end
    end
    return rows
end

function M.displayId(fleet,serverId,transportId)
    for _,row in ipairs(M.rows(fleet,serverId)) do
        if sameId(row.transportId,transportId) then return row.displayId end
    end
    return sameId(transportId,serverId) and 1 or nil
end

function M.transportId(row)
    return row and (row.transportId or row.id) or nil
end

return M
