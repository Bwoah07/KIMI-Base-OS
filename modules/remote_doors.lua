local M={id="remote_doors"}
local network=require("core.network")
local config=require("core.config")

local allowed={open=true,close=true,toggle=true,pulse=true}

local function copyTable(src)
  local out={}
  for k,v in pairs(src or{})do out[k]=v end
  return out
end

local function replay(events)
  if type(os.queueEvent)~="function"then return end
  for _,e in ipairs(events or{})do
    pcall(os.queueEvent,unpack(e))
  end
end

local function waitForDoorResult(target,cfg,action,timeoutSeconds)
  if type(os.pullEvent)~="function"or type(os.startTimer)~="function"then return nil,"ack unavailable"end
  local deferred={}
  local timer=os.startTimer(timeoutSeconds or .6)
  while true do
    local e={os.pullEvent()}
    if e[1]=="terminate"then replay(deferred);error("Terminated",0)end
    if e[1]=="timer"and e[2]==timer then
      replay(deferred)
      return nil,"timeout"
    end
    if e[1]=="rednet_message"then
      local sender,msg,protocol=e[2],e[3],e[4]
      local payload=type(msg)=="table"and type(msg.payload)=="table"and msg.payload or nil
      if tonumber(sender)==tonumber(target)and protocol==cfg.network.protocol and type(msg)=="table"and msg.kind=="module.command.result"and payload and payload.module=="doors"and tostring(payload.action or"")==tostring(action or"")then
        if type(os.cancelTimer)=="function"then pcall(os.cancelTimer,timer)end
        replay(deferred)
        return payload
      end
    end
    deferred[#deferred+1]=e
  end
end

function M.read()
  return{_status="online",_updated=os.epoch("utc")}
end

function M.handleCommand(action,args)
  args=type(args)=="table"and args or{}
  action=tostring(action or"")
  if not allowed[action]then error("unsupported remote door action")end
  local source=tostring(args._source or args.source or"")
  if source==""then error("door owner/source is missing")end

  local cfg=config.load()
  local selfId=tostring(os.getComputerID())
  if source=="server"or source==selfId then
    local doors=require("modules.doors")
    local localState=type(doors.read)=="function"and doors.read()or nil
    return doors.handleCommand(action,args,localState)
  end

  local target=tonumber(source)
  if not target then error("invalid door owner/source")end

  -- Pocket sends owner as `source`, not `_source`: `_source` is reserved by
  -- Main Base's generic dispatcher. Add ownership only for the destination.
  local routedArgs=copyTable(args)
  routedArgs._source=source
  local payload={module="doors",action=action,args=routedArgs,issuedBy=os.getComputerID(),remote=true}

  -- OPEN/CLOSE are idempotent, so retries are safe. Toggle/pulse are not and
  -- are deliberately sent once only. A successful rednet.send is NOT treated
  -- as door success: the owning room computer must answer after execution.
  local attempts=(action=="open"or action=="close")and 3 or 1
  local canAck=type(os.pullEvent)=="function"and type(os.startTimer)=="function"
  local lastErr="no reply"
  for attempt=1,attempts do
    local sent=network.send(target,cfg,"module.command",payload)
    if not sent then
      lastErr="send failed"
    elseif not canAck then
      return{queued=true,sourceId=target,attempts=attempt,unconfirmed=true}
    else
      local reply,err=waitForDoorResult(target,cfg,action,.6)
      if reply then
        if reply.ok==true then
          return{queued=false,confirmed=true,sourceId=target,attempts=attempt,result=reply.result}
        end
        error("door controller "..source.." failed: "..tostring(reply.result or reply.error or"unknown error"),0)
      end
      lastErr=err or"no reply"
    end
  end
  error("door controller "..source.." NO REPLY after "..tostring(attempts).." attempt(s): "..tostring(lastErr),0)
end

return M
