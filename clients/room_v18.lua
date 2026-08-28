-- Alpha83 wall-client policy: door setup is never automatic.
-- A remote computer is a normal wall/machine client until the operator runs
-- `door setup`. Local Builder priority is preserved, and explicit monitor pins
-- can override either normal view through the shared manual dashboard.
local normal=require("clients.room_v16")
local builder=require("clients.builder_dashboard")
local manual=require("clients.manual_dashboard")
local M={}

local function localBuilders(meta)
    local s=meta and meta.localState or {}; local b=s.builder
    return b and b.builders or {}
end

function M.init(cfg)
    if normal.init then normal.init(cfg) end
    if builder.init then builder.init(cfg) end
    manual.init(cfg)
end

function M.render(env,meta)
    local ok
    if #localBuilders(meta)>0 then ok=builder.render(env,meta)
    else ok=normal.render(env,meta) end
    manual.render(env,meta)
    return ok
end

function M.onState(state)
    if normal.onState then pcall(normal.onState,state) end
    if builder.onState then pcall(builder.onState,state) end
end

function M.onPeripheralChange(...)
    manual.reload()
    if builder.onPeripheralChange then pcall(builder.onPeripheralChange,...) end
    if normal.onPeripheralChange then return normal.onPeripheralChange(...) end
end

function M.handleEvent(ev,env,action)
    if manual.handleEvent(ev,env,action) then return true end
    if #localBuilders(nil)>0 and builder.handleEvent then
        local handled=builder.handleEvent(ev,env,action); if handled then return true end
    end
    if builder.handleEvent then
        local handled=builder.handleEvent(ev,env,action); if handled then return true end
    end
    if normal.handleEvent then return normal.handleEvent(ev,env,action) end
    return false
end

return M
