local base=require("roles.server_v3")
local fleetRegistry=require("core.fleet_registry")
local truth=require("core.fleet_truth")
local M={}

local function unpackEvent(e)local u=table.unpack or unpack;return u(e)end
local function copy(src)local out={};for k,v in pairs(src or{})do out[k]=v end;return out end

function M.run(cfg)
    local realPull=os.pullEvent
    local realSave=fleetRegistry.save
    local previousProof=rawget(_G,"kimiFleetProof")
    local proof={};local selfId=os.getComputerID()
    _G.kimiFleetProof=proof

    fleetRegistry.save=function(machines)
        local now=os.epoch("utc")
        for id,m in pairs(machines or{})do
            if tostring(id)~=tostring(selfId)and truth.shouldForget(m,now)then
                machines[id]=nil;proof[tostring(id)]=nil
            end
        end
        return realSave(machines)
    end

    os.pullEvent=function(filter)
        while true do
            local e={realPull(filter)}
            if e[1]=="rednet_message"and e[4]==cfg.network.protocol and type(e[3])=="table"and e[3].kind=="fleet.identity"then
                local sender=e[2];local payload=type(e[3].payload)=="table"and e[3].payload or{}
                local now=os.epoch("utc")
                proof[tostring(sender)]={
                    verifiedAt=now,sessionId=payload.sessionId,version=payload.version,
                    name=payload.name,role=payload.role,profile=payload.profile
                }
                -- Feed proven identity through the normal heartbeat path so the
                -- existing update authority and registry use the same live truth.
                local hello=copy(payload);hello.generated=now
                return"rednet_message",sender,{kind="fleet.hello",payload=hello,sent=e[3].sent},e[4]
            end
            return unpackEvent(e)
        end
    end

    local ok,res=xpcall(function()return base.run(cfg)end,function(err)return err end)
    os.pullEvent=realPull;fleetRegistry.save=realSave
    _G.kimiFleetProof=previousProof
    if not ok then error(res,0)end
    return res
end

return M
