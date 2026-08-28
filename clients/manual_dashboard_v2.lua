-- Alpha88 live-authoritative manual dashboard wrapper.
-- The original manual dashboard cached .kimi/monitors at process startup. That
-- allowed setup to save DOORS while the running renderer kept painting the old
-- FLEET/SENSORS assignment. Reload the tiny monitor map before every paint and
-- before touch dispatch so disk config is always the single source of truth.
local base=require("clients.manual_dashboard")
local M={}
for k,v in pairs(base)do M[k]=v end

local lastEnv,lastMeta

function M.reload()
    if base.reload then return base.reload()end
end

function M.init(cfg)
    lastEnv,lastMeta=nil,nil
    if base.init then base.init(cfg)end
    if base.reload then base.reload()end
end

function M.hasManualAssignments()
    if base.reload then base.reload()end
    return base.hasManualAssignments and base.hasManualAssignments()or false
end

function M.render(env,meta)
    lastEnv,lastMeta=env,meta
    if base.reload then base.reload()end
    if base.render then return base.render(env,meta)end
end

function M.handleEvent(ev,env,action)
    lastEnv=env or lastEnv
    if base.reload then base.reload()end
    -- A monitor assignment may have changed since the previous frame. Repaint
    -- once before interpreting a touch so hit targets belong to the new view,
    -- never the stale one that used to own this monitor.
    if ev and ev[1]=="monitor_touch"and lastEnv and base.render then
        base.render(lastEnv,lastMeta)
    end
    if base.handleEvent then return base.handleEvent(ev,lastEnv,action)end
    return false
end

return M
