local base=require("roles.node_v3")
local network=require("core.network")
local identity=require("core.fleet_identity")
local M={}

local function unpackEvent(e)local u=table.unpack or unpack;return u(e)end

function M.run(cfg)
    local realPull=os.pullEvent
    local session=identity.newSession("identify-node")
    os.pullEvent=function(filter)
        local e={realPull(filter)}
        if e[1]=="rednet_message"and e[4]==cfg.network.protocol and type(e[3])=="table"and e[3].kind=="fleet.identify"then
            local sender=e[2]
            network.send(sender,cfg,"fleet.identify.ack",identity.snapshot(cfg,"node","node",session))
        end
        return unpackEvent(e)
    end
    local ok,res=xpcall(function()return base.run(cfg)end,function(err)return err end)
    os.pullEvent=realPull
    if not ok then error(res,0)end
    return res
end

return M
