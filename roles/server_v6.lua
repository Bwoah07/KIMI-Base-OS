-- Dedicated lightweight fleet-presence packet.
-- Convert it into the proven server heartbeat path before the normal server
-- sees the event, so registry/update logic stays centralized and unchanged.
local base=require("roles.server_v5")
local M={}

local function unpackEvent(e)local u=table.unpack or unpack;return u(e)end

function M.run(cfg)
    local realPull=os.pullEvent
    os.pullEvent=function(filter)
        local e={realPull(filter)}
        if e[1]=="rednet_message" and e[4]==cfg.network.protocol and type(e[3])=="table" and e[3].kind=="fleet.heartbeat" then
            local msg=e[3]
            local payload=type(msg.payload)=="table" and msg.payload or{}
            payload.heartbeat=true
            return "rednet_message",e[2],{kind="fleet.hello",payload=payload,sent=msg.sent},e[4]
        end
        return unpackEvent(e)
    end
    local ok,res=xpcall(function()return base.run(cfg)end,function(err)return err end)
    os.pullEvent=realPull
    if not ok then error(res,0)end
    return res
end

return M
