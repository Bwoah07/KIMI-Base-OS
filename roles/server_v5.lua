local base=require("roles.server_v4")
local fleetRegistry=require("core.fleet_registry")
local M={}

local PURGE_MS=600000
local function unpackEvent(e)local u=table.unpack or unpack;return u(e)end

function M.run(cfg)
    local realPull=os.pullEvent
    local realSave=fleetRegistry.save
    local previousAck=rawget(_G,"kimiIdentifyAck")
    local ack={}
    local selfId=os.getComputerID()
    _G.kimiIdentifyAck=ack

    -- Fleet history is not a cemetery. A machine which has been absent for ten
    -- minutes is forgotten; if it ever comes back its normal heartbeat simply
    -- registers it again as a fresh fleet member.
    fleetRegistry.save=function(machines)
        local now=os.epoch("utc")
        for id,m in pairs(machines or{})do
            if tostring(id)~=tostring(selfId)then
                local seen=tonumber(m and m.lastSeen)
                if seen and now-seen>PURGE_MS then
                    machines[id]=nil
                    ack[tostring(id)]=nil
                end
            end
        end
        return realSave(machines)
    end

    -- An identify command is only useful if the target confirms that it
    -- actually received it. Consume these transport ACKs here and expose the
    -- latest confirmations to the local admin UI.
    os.pullEvent=function(filter)
        while true do
            local e={realPull(filter)}
            if e[1]=="rednet_message"and e[4]==cfg.network.protocol and type(e[3])=="table"and e[3].kind=="fleet.identify.ack"then
                local sender=e[2]
                local p=type(e[3].payload)=="table"and e[3].payload or{}
                ack[tostring(sender)]={
                    at=os.epoch("utc"),id=sender,name=p.name,role=p.role,
                    profile=p.profile,version=p.version,sessionId=p.sessionId
                }
            else
                return unpackEvent(e)
            end
        end
    end

    local ok,res=xpcall(function()return base.run(cfg)end,function(err)return err end)
    os.pullEvent=realPull
    fleetRegistry.save=realSave
    _G.kimiIdentifyAck=previousAck
    if not ok then error(res,0)end
    return res
end

return M
