local base=require("roles.node_v4")
local network=require("core.network")
local loader=require("core.module_loader")
local identity=require("core.fleet_identity")
local M={}
local HEARTBEAT_MS=2000

function M.run(cfg)
    local realSend=network.send
    local realFind=network.findServer
    local realReadAll=loader.readAll
    local serverId=nil
    local lastBeat=-math.huge
    local session=identity.newSession("heartbeat-node")

    local function now()
        local ok,v=pcall(os.epoch,"utc")
        return ok and tonumber(v) or 0
    end

    local function heartbeat()
        if not serverId then return false end
        local t=now()
        if t-lastBeat<HEARTBEAT_MS then return true end
        local payload=identity.snapshot(cfg,"node","node",session)
        payload.generated=t
        payload.heartbeat=true
        local ok=realSend(serverId,cfg,"fleet.heartbeat",payload)
        if ok==true then lastBeat=t end
        return ok==true
    end

    network.findServer=function(findCfg)
        local id=realFind(findCfg)
        if id then serverId=id end
        return id
    end

    network.send=function(target,sendCfg,kind,payload)
        if target and (kind=="fleet.hello" or kind=="telemetry.state" or kind=="fleet.identity") then serverId=target end
        return realSend(target,sendCfg,kind,payload)
    end

    loader.readAll=function(modules,previous)
        heartbeat()
        return realReadAll(modules,previous)
    end

    local ok,res=xpcall(function()return base.run(cfg)end,function(err)return err end)
    network.send=realSend
    network.findServer=realFind
    loader.readAll=realReadAll
    if not ok then error(res,0)end
    return res
end

return M
