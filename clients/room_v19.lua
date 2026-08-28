-- Alpha88 wall-client hard manual-screen authority.
-- Pinned monitors are hidden from automatic wall/Builder code for the complete
-- lifecycle, while the manual dashboard reloads saved assignments live.
local normal=require("clients.room_v16")
local builder=require("clients.builder_dashboard")
local manual=require("clients.manual_dashboard_v2")
local authority=require("core.monitor_authority")
local M={}

local function localBuilders(meta)
    local s=meta and meta.localState or{};local b=s.builder
    return b and b.builders or{}
end

function M.init(cfg)
    manual.init(cfg)
    authority.withAutomaticMonitorsHidden(function()
        if normal.init then normal.init(cfg)end
        if builder.init then builder.init(cfg)end
    end)
end

function M.render(env,meta)
    local ok
    authority.withAutomaticMonitorsHidden(function()
        if #localBuilders(meta)>0 then ok=builder.render(env,meta)
        else ok=normal.render(env,meta)end
    end)
    manual.render(env,meta)
    return ok
end

function M.onState(state)
    authority.withAutomaticMonitorsHidden(function()
        if normal.onState then pcall(normal.onState,state)end
        if builder.onState then pcall(builder.onState,state)end
    end)
end

function M.onPeripheralChange(...)
    manual.reload()
    local args={...}
    authority.withAutomaticMonitorsHidden(function()
        if builder.onPeripheralChange then pcall(builder.onPeripheralChange,table.unpack(args))end
        if normal.onPeripheralChange then pcall(normal.onPeripheralChange,table.unpack(args))end
    end)
end

function M.handleEvent(ev,env,action)
    if manual.handleEvent(ev,env,action)then return true end
    return authority.withAutomaticMonitorsHidden(function()
        if builder.handleEvent then
            local handled=builder.handleEvent(ev,env,action)
            if handled then return true end
        end
        if normal.handleEvent then return normal.handleEvent(ev,env,action)end
        return false
    end)
end

return M
