local setup=require("clients.room_v15")
local normal=require("clients.room_v16")
local M={}
local FLAG=".kimi/door_setup_request"

local function requested()
  if type(fs)~="table" or type(fs.exists)~="function" then return false end
  local ok,v=pcall(fs.exists,FLAG)
  return ok and v==true
end
local function localDoors(meta)
  local s=meta and meta.localState or {}; local d=s.doors
  return d and d.localDoors or {}
end
local function inSetup(meta)
  return requested() or #localDoors(meta)==0
end

function M.init(cfg)
  if setup.init then setup.init(cfg) end
  if normal.init then normal.init(cfg) end
end
function M.render(env,meta)
  if inSetup(meta) then return setup.render(env,meta) end
  return normal.render(env,meta)
end
function M.onState(state)
  if setup.onState then pcall(setup.onState,state) end
  if normal.onState then pcall(normal.onState,state) end
end
function M.onPeripheralChange(...)
  if requested() then
    if setup.onPeripheralChange then return setup.onPeripheralChange(...) end
  elseif normal.onPeripheralChange then return normal.onPeripheralChange(...) end
end
function M.handleEvent(ev,env,action)
  if requested() then return setup.handleEvent(ev,env,action) end
  if normal.handleEvent then return normal.handleEvent(ev,env,action) end
  return false
end

return M
