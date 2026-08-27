local base=require("roles.client_v4")
local identify=require("core.identify")
local M={}
local function unpackEvent(e)local u=table.unpack or unpack;return u(e)end
function M.run(cfg)
 local realPull=os.pullEvent;local active=false;local identifyTimer=nil
 os.pullEvent=function(filter)
  while true do
   if active then identify.paint(cfg,"CLIENT / "..tostring(cfg.profile or"wall"))end
   local e={realPull(filter)}
   if e[1]=="rednet_message"and e[4]==cfg.network.protocol and type(e[3])=="table"and e[3].kind=="fleet.identify"then
    local p=type(e[3].payload)=="table"and e[3].payload or{};active=true
    if identifyTimer and type(os.cancelTimer)=="function"then pcall(os.cancelTimer,identifyTimer)end
    identifyTimer=os.startTimer(math.max(2,math.min(20,tonumber(p.duration)or 8)));identify.paint(cfg,"CLIENT / "..tostring(cfg.profile or"wall"))
   elseif e[1]=="timer"and identifyTimer and e[2]==identifyTimer then
    active=false;identifyTimer=nil;return "kimi_identify_clear"
   else return unpackEvent(e)end
  end
 end
 local ok,res=xpcall(function()return base.run(cfg)end,function(err)return err end)
 os.pullEvent=realPull;active=false;if identifyTimer and type(os.cancelTimer)=="function"then pcall(os.cancelTimer,identifyTimer)end
 if not ok then error(res,0)end;return res
end
return M
