local monitorConfig=require("core.monitor_config")

local M={}
local guardDepth=0

local function pinnedSet()
    local ok,cfg=pcall(monitorConfig.load)
    if not ok or type(cfg)~="table"then return{}end
    local out={}
    for name,view in pairs(cfg.assignments or{})do
        if monitorConfig.normalizeView(view)~="auto"then out[tostring(name)]=true end
    end
    return out
end

function M.pinned()
    return pinnedSet()
end

function M.isPinned(name)
    return pinnedSet()[tostring(name or"")]==true
end

-- Run legacy/adaptive UI code inside a hard peripheral boundary. A monitor
-- explicitly assigned by the operator is not merely removed from getNames():
-- adaptive code also cannot wrap, call, or discover it through peripheral.find.
-- This makes manual monitor ownership authoritative instead of a repaint race.
function M.withAutomaticMonitorsHidden(fn,...)
    if type(fn)~="function"then return nil end
    if guardDepth>0 then return fn(...) end

    local pinned=pinnedSet()
    if next(pinned)==nil or type(peripheral)~="table"or type(peripheral.getNames)~="function"then
        return fn(...)
    end

    local originalGetNames=peripheral.getNames
    local originalWrap=peripheral.wrap
    local originalCall=peripheral.call
    local originalFind=peripheral.find
    local originalGetType=peripheral.getType
    local originalHasType=peripheral.hasType

    local function filteredNames()
        local ok,names=pcall(originalGetNames)
        if not ok then error(names,0)end
        local out={}
        for _,name in ipairs(type(names)=="table"and names or{})do
            if not pinned[tostring(name)]then out[#out+1]=name end
        end
        return out
    end

    local function matchesType(name,wanted)
        if type(originalHasType)=="function"then
            local ok,v=pcall(originalHasType,name,wanted)
            if ok then return v==true end
        end
        if type(originalGetType)=="function"then
            local ok,v=pcall(originalGetType,name)
            if ok then return tostring(v)==tostring(wanted)end
        end
        return false
    end

    peripheral.getNames=filteredNames
    if type(originalWrap)=="function"then
        peripheral.wrap=function(name)
            if pinned[tostring(name or"")]then return nil end
            return originalWrap(name)
        end
    end
    if type(originalCall)=="function"then
        peripheral.call=function(name,method,...)
            if pinned[tostring(name or"")]then
                error("monitor is manually owned by KIMI: "..tostring(name),0)
            end
            return originalCall(name,method,...)
        end
    end
    if type(originalFind)=="function"and type(originalWrap)=="function"then
        peripheral.find=function(wanted,filter)
            local found={}
            for _,name in ipairs(filteredNames())do
                if matchesType(name,wanted)then
                    local wrapped=originalWrap(name)
                    if wrapped and(type(filter)~="function"or filter(name,wrapped))then
                        found[#found+1]=wrapped
                    end
                end
            end
            return table.unpack(found)
        end
    end

    guardDepth=guardDepth+1
    local ok,a,b,c,d=pcall(fn,...)
    guardDepth=guardDepth-1

    peripheral.getNames=originalGetNames
    if originalWrap~=nil then peripheral.wrap=originalWrap end
    if originalCall~=nil then peripheral.call=originalCall end
    if originalFind~=nil then peripheral.find=originalFind end

    if not ok then error(a,0)end
    return a,b,c,d
end

return M
