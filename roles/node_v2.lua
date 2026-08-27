local base=require("roles.node")
local identify=require("core.identify")
local M={}
local function unpackEvent(e)local u=table.unpack or unpack;return u(e)end
function M.run(cfg)
 local realPull=os.pullEvent;local active=false;local timer=nil
 os.pullEvent=function(filter)
  while true do
   if active then identify.paint(cfg,"REMOTE NODE")end
   local e={realPull(filter)}
   if e[1]=="rednet_message"and e[4]==cfg.network.protocol and type(e[3])=="table"and e[3].kind=="fleet.identify"then
    local p=type(e[3].payload)=="table"and e[3].payload or{};active=true
    if timer and type(os.cancelTimer)=="function"then pcall(os.cancelTimer,timer)end
    timer=os.startTimer(math.max(2,math.min(20,tonumber(p.duration)or 8)));identify.paint(cfg,"REMOTE NODE")
   elseif e[1]=="timer"and timer and e[2]==timer then active=false;timer=nil
   else return unpackEvent(e)end
  end
 end
 local ok,res=xpcall(function()return base.run(cfg)end,function(err)return err end)
 os.pullEvent=realPull;active=false;if timer and type(os.cancelTimer)=="function"then pcall(os.cancelTimer,timer)end
 if not ok then error(res,0)end;return res
end
return M
