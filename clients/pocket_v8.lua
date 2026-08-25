-- Pocket v8 keeps the snappy v7 UI but routes door commands directly to the
-- owning room computer. Main Base remains the telemetry/state authority only.
local base=require("clients.pocket_v7")
local M={}
for k,v in pairs(base)do M[k]=v end

function M.handleEvent(ev,env,action)
    local function directAction(module,cmd,args)
        if module=="remote_doors" then module="direct_doors" end
        return action(module,cmd,args)
    end
    return base.handleEvent(ev,env,directAction)
end

return M
