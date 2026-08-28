local monitorConfig=require("core.monitor_config")

local M={}

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

-- Run legacy/adaptive UI code while hiding manually-owned monitors from
-- peripheral.getNames(). This prevents old renderers from repainting screens
-- which the operator explicitly pinned to a manual KIMI view.
function M.withAutomaticMonitorsHidden(fn,...)
    if type(fn)~="function"then return nil end
    local pinned=pinnedSet()
    if next(pinned)==nil or type(peripheral)~="table"or type(peripheral.getNames)~="function"then
        return fn(...)
    end
    local original=peripheral.getNames
    peripheral.getNames=function()
        local ok,names=pcall(original)
        if not ok then error(names,0)end
        local out={}
        for _,name in ipairs(type(names)=="table"and names or{})do
            if not pinned[tostring(name)]then out[#out+1]=name end
        end
        return out
    end
    local ok,a,b,c,d=pcall(fn,...)
    peripheral.getNames=original
    if not ok then error(a,0)end
    return a,b,c,d
end

return M
