local base = require("clients.room_v12")
local M = {}

local lastEnv, lastMeta
local invertTarget

local function localDoor(meta)
  local state = meta and meta.localState or {}
  local doors = state.doors and state.doors.localDoors or {}
  return doors[1]
end

local function isMonitor(name)
  local ok, t = pcall(peripheral.getType, name)
  if ok and t == "monitor" then return true end
  if ok and type(t) == "table" then
    for _, v in ipairs(t) do if v == "monitor" then return true end end
  end
  if type(peripheral.hasType) == "function" then
    local ok2, has = pcall(peripheral.hasType, name, "monitor")
    if ok2 and has == true then return true end
  end
  return false
end

local function primaryMonitor()
  local best
  local ok, names = pcall(peripheral.getNames)
  if not ok or type(names) ~= "table" then return nil end
  for _, name in ipairs(names) do
    if isMonitor(name) then
      local okWrap, mon = pcall(peripheral.wrap, name)
      if okWrap and mon then
        local okSize, w, h = pcall(mon.getSize)
        if okSize and tonumber(w) and tonumber(h) then
          local item = { name = name, mon = mon, w = tonumber(w), h = tonumber(h) }
          item.area = item.w * item.h
          if not best or item.area > best.area or (item.area == best.area and item.w > best.w) then best = item end
        end
      end
    end
  end
  return best
end

local function drawInvert(meta)
  invertTarget = nil
  local d = localDoor(meta)
  if not d or d.supportsModes == false then return end
  local e = primaryMonitor()
  if not e or e.h < 10 or e.w < 18 then return end

  local on = tostring(d.mode or "hold") == "invert"
  local label = on and "INVERT: ON" or "INVERT: OFF"
  local width = math.min(e.w - 4, math.max(15, #label + 4))
  local x1 = math.max(2, math.floor((e.w - width) / 2) + 1)
  local x2 = math.min(e.w - 1, x1 + width - 1)
  local y = math.max(4, e.h - 4)
  local bg = on and colors.orange or colors.gray

  pcall(e.mon.setBackgroundColor, bg)
  pcall(e.mon.setTextColor, colors.white)
  pcall(e.mon.setCursorPos, x1, y)
  pcall(e.mon.write, string.rep(" ", x2 - x1 + 1))
  local tx = x1 + math.max(0, math.floor(((x2 - x1 + 1) - #label) / 2))
  pcall(e.mon.setCursorPos, tx, y)
  pcall(e.mon.write, label)
  pcall(e.mon.setBackgroundColor, colors.black)

  invertTarget = { monitor = e.name, x1 = x1, x2 = x2, y = y, door = d }
end

function M.init(cfg)
  lastEnv, lastMeta, invertTarget = nil, nil, nil
  if base.init then return base.init(cfg) end
end

function M.render(env, meta)
  lastEnv, lastMeta = env, meta
  local ok, result = true, true
  if base.render then ok, result = pcall(base.render, env, meta) end
  if not ok then error(result, 0) end
  drawInvert(meta)
  return result
end

function M.onPeripheralChange(...)
  if base.onPeripheralChange then pcall(base.onPeripheralChange, ...) end
  if lastMeta then drawInvert(lastMeta) end
end

function M.handleEvent(ev, env, action)
  if ev[1] == "monitor_touch" and invertTarget then
    local name, x, y = ev[2], tonumber(ev[3]), tonumber(ev[4])
    local t = invertTarget
    if name == t.monitor and x and y and x >= t.x1 and x <= t.x2 and y == t.y then
      local d = localDoor(lastMeta) or t.door
      if not d then return false, "door not configured" end
      local newMode = tostring(d.mode or "hold") == "invert" and "hold" or "invert"
      local ok, result = action("__local_doors", "configure_local", {
        _source = tostring(os.getComputerID()),
        target = d.target,
        side = d.side,
        mode = newMode,
      })
      if ok ~= false and lastMeta and lastMeta.localState and lastMeta.localState.doors then
        d.mode = newMode
      end
      drawInvert(lastMeta)
      return ok, result
    end
  end
  if base.handleEvent then return base.handleEvent(ev, env, action) end
  return false
end

return M
