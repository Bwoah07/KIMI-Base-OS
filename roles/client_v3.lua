-- Client event bridge for final Main Base command results.
-- The normal client role already receives rednet traffic, but historically it
-- ignored command.result. Pocket v6 needs that final transaction result so its
-- UI reflects confirmed door state instead of a blind optimistic timer.
local base=require("roles.client_v2")
local M={}

local function unpackEvent(e)
    local u=table.unpack or unpack
    return u(e)
end

function M.run(cfg)
    local realPullEvent=os.pullEvent

    os.pullEvent=function(filter)
        local e={realPullEvent(filter)}
        if e[1]=="rednet_message" and e[4]==cfg.network.protocol and type(e[3])=="table" then
            local msg=e[3]
            if msg.kind=="command.result" then
                local payload=type(msg.payload)=="table" and msg.payload or {}
                return "kimi_command_result",payload,e[2]
            end
        end
        return unpackEvent(e)
    end

    local ok,result=xpcall(function()return base.run(cfg)end,function(err)return err end)
    os.pullEvent=realPullEvent
    if not ok then error(result,0) end
    return result
end

return M
