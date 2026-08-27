-- Real fleet heartbeat transport.
-- Presence is emitted before hardware/module scans so slow telemetry cannot make
-- an otherwise healthy client flap ONLINE/OFFLINE in the Command Center.
local base=require("roles.client_v7")
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
    local profile=tostring(cfg and cfg.profile or "wall")
    local session=identity.newSession("heartbeat-client")

    local function now()
        local ok,v=pcall(os.epoch,"utc")
        return ok and tonumber(v) or 0
    end

    local function heartbeat(force)
        if not serverId then return false end
        local t=now()
        if not force and t-lastBeat<HEARTBEAT_MS then return true end
        local payload=identity.snapshot(cfg,"client",profile,session)
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
        if target and (kind=="fleet.hello" or kind=="state.get" or kind=="telemetry.state" or kind=="fleet.identity") then
            serverId=target
            -- Pocket deliberately suppresses fleet.hello/telemetry in client_v4,
            -- but state.get reaches here, so it still gets a genuine heartbeat.
            if kind=="state.get" then heartbeat(false) end
        end
        return realSend(target,sendCfg,kind,payload)
    end

    loader.readAll=function(modules,previous)
        -- This runs before the actual peripheral work. If AE2/Flux/Builder or a
        -- sensor is slow, Main Base has already heard that this computer is alive.
        heartbeat(false)
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
