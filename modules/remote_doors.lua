local M={id="remote_doors"}
local network=require("core.network")
local config=require("core.config")

local allowed={open=true,close=true,toggle=true,pulse=true}

local function copyTable(src)
  local out={}
  for k,v in pairs(src or{})do out[k]=v end
  return out
end

function M.read()
  return{_status="online",_updated=os.epoch("utc")}
end

function M.handleCommand(action,args)
  args=type(args)=="table"and args or{}
  if not allowed[tostring(action or"")]then error("unsupported remote door action")end
  local source=tostring(args._source or args.source or"")
  if source==""then error("door owner/source is missing")end

  local cfg=config.load()
  local selfId=tostring(os.getComputerID())
  if source=="server"or source==selfId then
    local doors=require("modules.doors")
    -- Remote control must use the exact same saved door record as the room panel.
    -- In particular this preserves mode="invert", pulse settings and actuator kind.
    local localState=type(doors.read)=="function"and doors.read()or nil
    return doors.handleCommand(action,args,localState)
  end

  local target=tonumber(source)
  if not target then error("invalid door owner/source")end

  -- Pocket intentionally sends owner as `source`, not `_source`. `_source` is
  -- reserved by Main Base's generic command dispatcher and would make it bypass
  -- this router. Only the destination room computer needs `_source` for its
  -- ownership check, so add it here after routing has been resolved.
  local routedArgs=copyTable(args)
  routedArgs._source=source
  local payload={module="doors",action=action,args=routedArgs,issuedBy=os.getComputerID(),remote=true}
  local sent=network.send(target,cfg,"module.command",payload)
  if not sent then error("failed to reach door controller "..source)end
  return{queued=true,sourceId=target}
end

return M
