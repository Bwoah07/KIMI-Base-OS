local setup=require("clients.room_v15")
local normal=require("clients.room_v16")
local builder=require("clients.builder_dashboard")
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
local function localBuilders(meta)
  local s=meta and meta.localState or{};local b=s.builder
  return b and b.builders or{}
end
local function inSetup(meta)
  -- Builder nodes used to be hijacked by the automatic door wizard merely
  -- because they did not own a door. Explicit setup still always wins, while
  -- a detected Builder gets its operational screen immediately.
  return requested() or(#localDoors(meta)==0 and#localBuilders(meta)==0)
end

function M.init(cfg)
  if setup.init then setup.init(cfg) end
  if normal.init then normal.init(cfg) end
  if builder.init then builder.init(cfg) end
end
function M.render(env,meta)
  if inSetup(meta) then return setup.render(env,meta) end
  if #localBuilders(meta)>0 then return builder.render(env,meta)end
  return normal.render(env,meta)
end
function M.onState(state)
  if setup.onState then pcall(setup.onState,state) end
  if normal.onState then pcall(normal.onState,state) end
  if builder.onState then pcall(builder.onState,state)end
end
function M.onPeripheralChange(...)
  if requested() then
    if setup.onPeripheralChange then return setup.onPeripheralChange(...) end
  else
    if builder.onPeripheralChange then pcall(builder.onPeripheralChange,...)end
    if normal.onPeripheralChange then return normal.onPeripheralChange(...) end
  end
end
function M.handleEvent(ev,env,action)
  if requested() then return setup.handleEvent(ev,env,action) end
  if builder.handleEvent then local handled=builder.handleEvent(ev,env,action);if handled then return handled end end
  if normal.handleEvent then return normal.handleEvent(ev,env,action) end
  return false
end

return M
