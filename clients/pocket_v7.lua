-- Thin event bridge over the transaction-aware Pocket v6 UI.
local base=require("clients.pocket_v6")
local M={}
for k,v in pairs(base)do M[k]=v end

function M.handleEvent(ev,env,action)
    if type(ev)=="table" and ev[1]=="kimi_command_result" then
        local handled=type(base.onCommandResult)=="function" and base.onCommandResult(ev[2]) or false
        if handled and type(base.render)=="function" then base.render(env,{connected=true}) end
        return handled
    end
    return base.handleEvent(ev,env,action)
end

return M
