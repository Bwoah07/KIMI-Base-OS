-- Alpha73 compatibility wrapper: admin v19 uses os.epoch for fleet/animation
-- timing, but legacy/mocked ComputerCraft environments may not expose it.
local base=require("clients.admin_v22")
local M={}
for k,v in pairs(base)do M[k]=v end

local function fallbackEpoch()
 local ok,t=pcall(os.time,"ingame")
 if not ok then t=0 end
 return math.floor((tonumber(t)or 0)*1000)
end

local function withEpoch(fn,...)
 local real=os.epoch
 if type(real)~="function"then os.epoch=fallbackEpoch end
 local args={...}
 local ok,a,b,c=pcall(fn,table.unpack(args))
 if type(real)=="function"then os.epoch=real else os.epoch=nil end
 if not ok then error(a,0)end
 return a,b,c
end

function M.render(env,meta)return withEpoch(base.render,env,meta)end
function M.handleEvent(ev,env,action)
 if not base.handleEvent then return false end
 return withEpoch(base.handleEvent,ev,env,action)
end
return M
