local base=require("roles.client_v5")
local network=require("core.network")
local identity=require("core.fleet_identity")
local M={}

function M.run(cfg)
    local realSend=network.send
    local session=identity.newSession("client")
    local profile=tostring(cfg and cfg.profile or"wall")
    network.send=function(target,sendCfg,kind,payload)
        local ok=realSend(target,sendCfg,kind,payload)
        if kind=="fleet.hello"or(profile=="pocket"and kind=="state.get")then
            realSend(target,sendCfg,"fleet.identity",identity.snapshot(cfg,"client",profile,session))
        end
        return ok
    end
    local ok,res=xpcall(function()return base.run(cfg)end,function(err)return err end)
    network.send=realSend
    if not ok then error(res,0)end
    return res
end

return M
