-- Alpha83 manual-screen overlay.
-- Existing adaptive planning remains the default. Any monitor explicitly pinned
-- by `setup monitors` is repainted by the shared manual dashboard and consumes
-- its own touch events before the legacy automatic UI sees them.
local base=require("clients.admin_v30")
local manual=require("clients.manual_dashboard")
local M={}
for k,v in pairs(base)do M[k]=v end

local lastEnv,lastMeta

function M.init(cfg)
    lastEnv,lastMeta=nil,nil
    manual.init(cfg)
    if base.init then return base.init(cfg) end
end

function M.render(env,meta)
    lastEnv,lastMeta=env,meta
    local ok=true
    if base.render then ok=base.render(env,meta) end
    manual.render(env,meta)
    return ok
end

function M.onPeripheralChange(...)
    manual.reload()
    if base.onPeripheralChange then return base.onPeripheralChange(...) end
end

function M.handleEvent(ev,env,action)
    lastEnv=env or lastEnv
    if manual.handleEvent(ev,lastEnv,action) then
        if lastEnv then M.render(lastEnv,lastMeta) end
        return true
    end
    local handled=base.handleEvent and base.handleEvent(ev,env,action)or false
    if handled and lastEnv then M.render(lastEnv,lastMeta) end
    return handled
end

return M
