local base=require("roles.client_v4")
local identify=require("core.identify")
local loader=require("core.module_loader")
local M={}
local function unpackEvent(e)local u=table.unpack or unpack;return u(e)end
local function wallProfile(p)local n=tostring(p or"");return n=="wall"or n=="room"or n:match("^adaptive")~=nil end
function M.run(cfg)
 local realPull=os.pullEvent;local realReadAll=loader.readAll;local active=false;local identifyTimer=nil;local lastBuilder=0
 -- client_v4 intentionally keeps wall polling lean. Inject Builder telemetry on
 -- the same slow cadence without adding it to the fast door/sensor scan.
 if wallProfile(cfg and cfg.profile)then
  loader.readAll=function(modules,previous)
   local out=realReadAll(modules,previous);local now=os.epoch("utc")
   if now-lastBuilder>=5000 then
    local ok,b=pcall(require,"modules.builder");if ok and b and type(b.read)=="function"then local ok2,v=pcall(b.read,previous and previous.builder);if ok2 and type(v)=="table"then out.builder=v end end
    lastBuilder=now
   elseif previous and previous.builder~=nil then out.builder=previous.builder end
   return out
  end
 end
 os.pullEvent=function(filter)
  while true do
   if active then identify.paint(cfg,"CLIENT / "..tostring(cfg.profile or"wall"))end
   local e={realPull(filter)}
   if e[1]=="rednet_message"and e[4]==cfg.network.protocol and type(e[3])=="table"and e[3].kind=="fleet.identify"then
    local p=type(e[3].payload)=="table"and e[3].payload or{};active=true
    if identifyTimer and type(os.cancelTimer)=="function"then pcall(os.cancelTimer,identifyTimer)end
    identifyTimer=os.startTimer(math.max(2,math.min(20,tonumber(p.duration)or 8)));identify.paint(cfg,"CLIENT / "..tostring(cfg.profile or"wall"))
   elseif e[1]=="timer"and identifyTimer and e[2]==identifyTimer then active=false;identifyTimer=nil;return "kimi_identify_clear"
   else return unpackEvent(e)end
  end
 end
 local ok,res=xpcall(function()return base.run(cfg)end,function(err)return err end)
 os.pullEvent=realPull;loader.readAll=realReadAll;active=false;if identifyTimer and type(os.cancelTimer)=="function"then pcall(os.cancelTimer,identifyTimer)end
 if not ok then error(res,0)end;return res
end
return M
