-- Alpha88 hard manual-screen authority.
-- A pinned monitor is hidden from every legacy/adaptive lifecycle path,
-- including init, and the manual dashboard reloads its saved mapping live.
local base=require("clients.admin_v30")
local manual=require("clients.manual_dashboard_v2")
local authority=require("core.monitor_authority")
local M={}
for k,v in pairs(base)do M[k]=v end

local lastEnv,lastMeta

function M.init(cfg)
    lastEnv,lastMeta=nil,nil
    manual.init(cfg)
    if base.init then
        return authority.withAutomaticMonitorsHidden(function()return base.init(cfg)end)
    end
end

function M.render(env,meta)
    lastEnv,lastMeta=env,meta
    local ok=true
    if base.render then
        ok=authority.withAutomaticMonitorsHidden(function()return base.render(env,meta)end)
    end
    manual.render(env,meta)
    return ok
end

function M.onPeripheralChange(...)
    manual.reload()
    if base.onPeripheralChange then
        local args={...}
        return authority.withAutomaticMonitorsHidden(function()return base.onPeripheralChange(table.unpack(args))end)
    end
end

function M.handleEvent(ev,env,action)
    lastEnv=env or lastEnv
    if manual.handleEvent(ev,lastEnv,action)then
        if lastEnv then M.render(lastEnv,lastMeta)end
        return true
    end
    local handled=false
    if base.handleEvent then
        handled=authority.withAutomaticMonitorsHidden(function()return base.handleEvent(ev,env,action)end)or false
    end
    if handled and lastEnv then M.render(lastEnv,lastMeta)end
    return handled
end

return M
