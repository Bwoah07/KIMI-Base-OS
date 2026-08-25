local M={id="remote_doors_async"}

function M.read()
  return{_status="online",_updated=os.epoch("utc")}
end

function M.handleCommand(action,args)
  action=tostring(action or"")
  if action~="open"and action~="close"then error("async door bridge supports explicit open/close only")end
  local hook=rawget(_G,"kimiRemoteDoorAsync")
  if type(hook)~="function"then error("Main Base async door transport is unavailable")end
  return hook(action,type(args)=="table"and args or{})
end

return M
