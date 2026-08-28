local M={id="fleet_admin"}
local registry=require("core.fleet_registry")
local health=require("core.fleet_health")

local function now()
    if type(os.epoch)=="function" then
        local ok,v=pcall(os.epoch,"utc")
        if ok and tonumber(v) then return tonumber(v) end
    end
    return 0
end

function M.read()
    return {_status="online",_updated=now()}
end

function M.handleCommand(action,args)
    if tostring(action)~="forget" then error("unsupported fleet admin action",0) end
    args=type(args)=="table" and args or {}
    local target=tonumber(args.id or args.transportId)
    if not target then error("missing fleet transport id",0) end
    local selfId=tonumber(os.getComputerID())
    if target==selfId then error("Main Server cannot forget itself",0) end

    local machines=registry.load()
    local record=machines[target]
    if not record then return {forgot=false,alreadyGone=true,id=target} end

    local status,age=health.reachability(target,record,selfId,now())
    if status~="OFFLINE" then
        error("refusing to forget reachable fleet member ("..tostring(status)..")",0)
    end

    machines[target]=nil
    registry.save(machines)

    -- The running server owns an in-memory fleet table and may persist it again.
    -- Reboot immediately after the durable delete so the clean registry becomes
    -- authoritative before any old in-memory copy can resurrect the ghost.
    if type(os.reboot)=="function" then os.reboot() end
    return {forgot=true,id=target,ageMs=age}
end

return M
