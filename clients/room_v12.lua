local M = {}

local C = {
  bg = colors.black,
  text = colors.white,
  dim = colors.lightGray,
  good = colors.lime,
  warn = colors.orange,
  bad = colors.red,
  action = colors.blue,
  panel = colors.gray,
}

local cfg = {}
local targets = {}
local lastEnv, lastMeta
local lastAction = "READY"
local lastActionOk = true
local lastTouch = "NONE"

local function upper(v) return tostring(v or ""):upper() end
local function nice(v)
  return upper(tostring(v or ""):gsub("minecraft:", ""):gsub("[_%-]", " "):gsub("(%l)(%u)", "%1 %2"))
end
local function gameTime()
  local ok, t = pcall(os.time, "ingame")
  t = ok and tonumber(t) or 0
  local h = math.floor(t % 24)
  local m = math.floor((((t % 24) - h) * 60) + 0.5) % 60
  return string.format("%02d:%02d", h, m)
end
local function roomName()
  local label = type(os.getComputerLabel) == "function" and os.getComputerLabel() or nil
  if label and tostring(label):match("%S") and not tostring(label):match("^KIMI[%s%-]?%d+$") then return upper(label) end
  if cfg.name and tostring(cfg.name):match("%S") and not tostring(cfg.name):match("^KIMI[%s%-]?%d+$") then return upper(cfg.name) end
  return "ROOM PANEL"
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

local function detectMonitors()
  local out = {}
  local ok, names = pcall(peripheral.getNames)
  if not ok or type(names) ~= "table" then return out end
  for _, name in ipairs(names) do
    if isMonitor(name) then
      local okWrap, mon = pcall(peripheral.wrap, name)
      if okWrap and mon then
        local scale = 1
        pcall(mon.setTextScale, scale)
        local okSize, w, h = pcall(mon.getSize)
        if okSize and tonumber(w) and tonumber(h) then
          w, h = tonumber(w), tonumber(h)
          if w < 22 or h < 12 then
            scale = 0.5
            pcall(mon.setTextScale, scale)
            local ok2, w2, h2 = pcall(mon.getSize)
            if ok2 then w, h = tonumber(w2) or w, tonumber(h2) or h end
          end
          out[#out + 1] = { name = name, mon = mon, w = w, h = h, scale = scale, area = w * h }
        end
      end
    end
  end
  table.sort(out, function(a, b)
    if a.area ~= b.area then return a.area > b.area end
    if a.w ~= b.w then return a.w > b.w end
    return a.name < b.name
  end)
  return out
end

local function put(e, x, y, text, fg, bg)
  if y < 1 or y > e.h or x > e.w then return end
  x = math.max(1, x)
  text = tostring(text or "")
  e.mon.setCursorPos(x, y)
  e.mon.setTextColor(fg or C.text)
  e.mon.setBackgroundColor(bg or C.bg)
  e.mon.write(text:sub(1, math.max(0, e.w - x + 1)))
end
local function fill(e, x1, y1, x2, y2, bg)
  x1, x2 = math.max(1, x1), math.min(e.w, x2)
  y1, y2 = math.max(1, y1), math.min(e.h, y2)
  if x2 < x1 or y2 < y1 then return end
  for y = y1, y2 do put(e, x1, y, string.rep(" ", x2 - x1 + 1), C.text, bg) end
end
local function center(e, y, text, fg, bg, x1, x2)
  x1, x2 = x1 or 1, x2 or e.w
  local width = math.max(1, x2 - x1 + 1)
  text = tostring(text or "")
  if #text > width then text = text:sub(1, width) end
  put(e, x1 + math.max(0, math.floor((width - #text) / 2)), y, text, fg, bg)
end
local function rule(e, y)
  if y >= 1 and y <= e.h then put(e, 1, y, string.rep("-", e.w), C.panel) end
end
local function prep(e)
  pcall(e.mon.setTextScale, e.scale)
  e.mon.setBackgroundColor(C.bg)
  e.mon.setTextColor(C.text)
  e.mon.clear()
  targets[e.name] = {}
end
local function register(e, t)
  t.monitor = e
  targets[e.name][#targets[e.name] + 1] = t
end
local function button(e, name, x1, y1, x2, y2, label, data, bg)
  x1, x2 = math.max(2, x1), math.min(e.w - 1, x2)
  y1, y2 = math.max(1, y1), math.min(e.h, y2)
  fill(e, x1, y1, x2, y2, bg or C.action)
  center(e, math.floor((y1 + y2) / 2), label, C.text, bg or C.action, x1 + 2, x2 - 2)
  register(e, { name = name, x1 = x1, y1 = y1, x2 = x2, y2 = y2, label = label, data = data })
end

local function localState(meta) return meta and meta.localState or {} end
local function localDoors(meta)
  local d = localState(meta).doors
  return d and d.localDoors or {}
end
local function candidateList(meta)
  local d = localState(meta).doors
  local raw = d and d.candidates or {}
  local dedicated, fallback = {}, {}
  for _, c in ipairs(raw) do
    if c.localConfigured ~= true then
      if tostring(c.target) == "computer" then fallback[#fallback + 1] = c else dedicated[#dedicated + 1] = c end
    end
  end
  return #dedicated > 0 and dedicated or fallback
end
local function sensorInfo(meta, env)
  local a = localState(meta).attachments or {}
  local localSensors = a.sensors or {}
  if #localSensors > 0 then return localSensors[1], #localSensors, "LOCAL" end
  local globalSensors = env and env.state and env.state.attachments and env.state.attachments.sensors or {}
  if #globalSensors > 0 then return globalSensors[1], #globalSensors, "BASE" end
  return nil, 0, "NONE"
end
local function sensorMetric(s)
  local m = s and s.metrics or {}
  local order = { {"temperature", "TEMP"}, {"onlinePlayers", "PLAYERS"}, {"biome", "BIOME"}, {"dimension", "DIM"}, {"radiationRaw", "RAD"} }
  for _, p in ipairs(order) do if m[p[1]] ~= nil then return p[2], nice(m[p[1]]) end end
  return "STATUS", nice(s and s.summary or "ONLINE")
end

local function terminalStatus(meta, env, mons)
  local ok = pcall(function()
    local doors = localDoors(meta)
    local d = doors[1]
    local _, sensorCount, sensorScope = sensorInfo(meta, env)
    term.setBackgroundColor(C.bg)
    term.setTextColor(C.text)
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(C.good)
    print("KIMI ROOM")
    term.setTextColor(C.text)
    print(roomName())
    print("")
    print((meta and meta.connected == false) and "BASE: OFFLINE" or "BASE: ONLINE")
    print("MONITORS: " .. tostring(#mons))
    if d then
      print("DOOR: " .. tostring(d.name or "LOCAL DOOR"))
      print("STATE: " .. (d.open and "OPEN" or "CLOSED"))
      print("REDSTONE: " .. (d.signal and "ON" or "OFF"))
      if d.inputReadable then print("INPUT: " .. (d.inputSignal and "ON" or "OFF")) end
    else
      print("DOOR: NOT CONFIGURED")
    end
    print("SENSORS: " .. tostring(sensorCount) .. " " .. sensorScope)
    print("")
    term.setTextColor(lastActionOk and C.good or C.bad)
    print("LAST: " .. tostring(lastAction))
    term.setTextColor(C.dim)
    print("TOUCH: " .. tostring(lastTouch))
    term.setTextColor(C.text)
  end)
  return ok
end

local function header(e, meta, env)
  put(e, 2, 1, roomName(), C.text)
  put(e, math.max(2, e.w - 6), 1, gameTime(), C.dim)
  rule(e, 2)
  local _, n, scope = sensorInfo(meta, env)
  put(e, 2, 3, meta and meta.connected == false and "BASE OFFLINE" or "BASE ONLINE", meta and meta.connected == false and C.warn or C.good)
  if n > 0 then
    local s = scope .. " SENS " .. n
    put(e, math.max(2, e.w - #s - 1), 3, s, C.good)
  end
end

local function sensorStrip(e, meta, env)
  local y = e.h - 3
  rule(e, y)
  local s, n, scope = sensorInfo(meta, env)
  if s then
    local k, v = sensorMetric(s)
    put(e, 2, y + 1, scope .. " SENSOR" .. (n == 1 and "" or "S") .. " " .. n, C.dim)
    put(e, 2, y + 2, k .. "  " .. v, C.good)
  else
    put(e, 2, y + 1, "SENSORS NONE", C.warn)
    put(e, 2, y + 2, "NO BASE SENSOR DATA", C.dim)
  end
end

local function renderDoor(e, env, meta)
  local d = localDoors(meta)[1]
  if not d then return false end
  local mode = tostring(d.mode or "hold")
  local state = d.online == false and "OFFLINE" or (d.open and "OPEN" or "CLOSED")
  local stateColor = d.online == false and C.bad or (d.open and C.good or C.text)
  center(e, 5, upper(d.name or "DOOR"), C.dim, nil, 2, e.w - 1)
  center(e, 7, state, stateColor, nil, 2, e.w - 1)
  center(e, 8, d.signal and "REDSTONE ON" or "REDSTONE OFF", d.signal and C.good or C.dim, nil, 2, e.w - 1)
  if d.inputReadable then center(e, 9, d.inputSignal and "INPUT ON" or "INPUT OFF", C.dim, nil, 2, e.w - 1) end
  local label = mode == "pulse" and "TRIGGER DOOR" or (d.open and "CLOSE DOOR" or "OPEN DOOR")
  button(e, "door_toggle", 3, 11, e.w - 2, math.min(e.h - 5, 16), label, {
    _source = tostring(os.getComputerID()), target = d.target, side = d.side, id = d.id
  }, d.open and C.good or C.action)
  if lastAction ~= "READY" then
    center(e, math.min(e.h - 4, 18), tostring(lastAction), lastActionOk and C.good or C.bad, nil, 2, e.w - 1)
  end
  sensorStrip(e, meta, env)
  return true
end

local function groupCandidates(list)
  local order, groups = {}, {}
  for _, c in ipairs(list) do
    local k = tostring(c.target)
    if not groups[k] then groups[k] = {}; order[#order + 1] = k end
    groups[k][#groups[k] + 1] = c
  end
  table.sort(order, function(a, b)
    local pa = groups[a][1] and tonumber(groups[a][1].priority) or 5
    local pb = groups[b][1] and tonumber(groups[b][1].priority) or 5
    if pa ~= pb then return pa < pb end
    return a < b
  end)
  return order, groups
end

local function renderSetup(e, env, meta)
  local list = candidateList(meta)
  center(e, 6, "SET UP DOOR", C.text, nil, 2, e.w - 1)
  if #list == 0 then
    center(e, 9, "NO REDSTONE ACTUATOR", C.warn, nil, 2, e.w - 1)
    center(e, 11, "CONNECT REDSTONE / INTEGRATOR", C.dim, nil, 2, e.w - 1)
    sensorStrip(e, meta, env)
    return
  end
  local order, groups = groupCandidates(list)
  local chosen = groups[order[1]] or {}
  local first = chosen[1]
  center(e, 8, nice(first and (first.type or first.controller) or "CONTROLLER"), C.dim, nil, 2, e.w - 1)
  if first and #chosen == 1 and not first.side then
    button(e, "door_register", 3, 11, e.w - 2, 15, "USE THIS ACTUATOR", { target = first.target, side = nil, name = roomName() })
  else
    center(e, 10, "TAP REDSTONE SIDE", C.dim, nil, 2, e.w - 1)
    local left, right, gap = 3, e.w - 2, 1
    local cell = math.floor((right - left + 1 - gap * 2) / 3)
    for i, c in ipairs(chosen) do
      if i > 6 then break end
      local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
      local x1 = left + col * (cell + gap)
      local x2 = col == 2 and right or x1 + cell - 1
      local y = 12 + row * 3
      button(e, "door_register", x1, y, x2, y + 1, nice(c.side or c.label or "OUT"), { target = c.target, side = c.side, name = roomName() })
    end
  end
  sensorStrip(e, meta, env)
end

local function renderRoom(e, env, meta)
  prep(e)
  header(e, meta, env)
  if not renderDoor(e, env, meta) then renderSetup(e, env, meta) end
end
local function renderSensor(e, env, meta)
  prep(e)
  header(e, meta, env)
  local s, n, scope = sensorInfo(meta, env)
  center(e, 7, scope .. " SENSORS " .. n, C.dim, nil, 2, e.w - 1)
  if s then
    local k, v = sensorMetric(s)
    center(e, 10, k, C.dim, nil, 2, e.w - 1)
    center(e, 12, v, C.good, nil, 2, e.w - 1)
  else
    center(e, 11, "NO SENSOR DATA", C.warn, nil, 2, e.w - 1)
  end
end
local function renderStatus(e, env, meta)
  prep(e)
  header(e, meta, env)
  center(e, math.max(7, math.floor(e.h / 2)), gameTime(), C.text, nil, 2, e.w - 1)
end

local function drawError(e, err)
  pcall(e.mon.setTextScale, 1)
  pcall(e.mon.setBackgroundColor, C.bg)
  pcall(e.mon.setTextColor, C.bad)
  pcall(e.mon.clear)
  pcall(e.mon.setCursorPos, 2, 2)
  pcall(e.mon.write, "KIMI UI ERROR")
  pcall(e.mon.setTextColor, C.text)
  local msg = tostring(err or "unknown")
  local width = math.max(8, e.w - 2)
  for i = 1, math.min(5, math.ceil(#msg / width)) do
    pcall(e.mon.setCursorPos, 2, 3 + i)
    pcall(e.mon.write, msg:sub((i - 1) * width + 1, i * width))
  end
end

local function renderAll(env, meta)
  local mons = detectMonitors()
  for i, e in ipairs(mons) do
    if i == 1 then renderRoom(e, env, meta)
    elseif i == 2 then renderSensor(e, env, meta)
    else renderStatus(e, env, meta) end
  end
  terminalStatus(meta, env, mons)
end
local function safeRender(env, meta)
  local ok, err = pcall(renderAll, env, meta)
  if ok then return true end
  for _, e in ipairs(detectMonitors()) do drawError(e, err) end
  lastAction = "UI ERROR: " .. tostring(err)
  lastActionOk = false
  terminalStatus(meta, env, detectMonitors())
  return false, err
end

local function pressed(t)
  local e = t and t.monitor
  if not e then return end
  fill(e, t.x1, t.y1, t.x2, t.y2, C.panel)
  center(e, math.floor((t.y1 + t.y2) / 2), "WORKING...", C.text, C.panel, t.x1 + 2, t.x2 - 2)
end
local function actionError(t, err)
  local e = t and t.monitor
  if not e then return end
  fill(e, t.x1, t.y1, t.x2, t.y2, C.bad)
  center(e, math.floor((t.y1 + t.y2) / 2), "ERROR", C.text, C.bad, t.x1 + 2, t.x2 - 2)
  if e.h >= t.y2 + 2 then center(e, t.y2 + 2, tostring(err), C.bad, nil, 2, e.w - 1) end
end

function M.init(c)
  cfg = c or {}
  targets = {}
  lastAction = "READY"
  lastActionOk = true
  lastTouch = "NONE"
end
function M.render(env, meta)
  lastEnv, lastMeta = env, meta
  return safeRender(env, meta)
end
function M.onPeripheralChange()
  if lastEnv then safeRender(lastEnv, lastMeta) end
end
function M.handleEvent(ev, env, action)
  if ev[1] ~= "monitor_touch" then return false end
  local name, x, y = ev[2], tonumber(ev[3]), tonumber(ev[4])
  if not name or not x or not y then return false end
  lastTouch = tostring(name) .. " @ " .. tostring(x) .. "," .. tostring(y)
  for _, t in ipairs(targets[name] or {}) do
    if x >= t.x1 and x <= t.x2 and y >= t.y1 and y <= t.y2 then
      pressed(t)
      lastAction = "SENDING..."
      lastActionOk = true
      terminalStatus(lastMeta, lastEnv, detectMonitors())
      local ok, result
      if t.name == "door_toggle" then
        local d = localDoors(lastMeta)[1]
        local mode = d and tostring(d.mode or "hold") or "hold"
        ok, result = action("__local_doors", mode == "pulse" and "pulse" or "toggle", t.data)
      elseif t.name == "door_register" then
        ok, result = action("__local_doors", "register_local", t.data)
      else
        return false
      end
      if ok == false then
        lastAction = "ERROR: " .. tostring(result)
        lastActionOk = false
        actionError(t, result)
      else
        lastAction = "DONE"
        lastActionOk = true
      end
      safeRender(lastEnv, lastMeta)
      return ok, result
    end
  end
  lastAction = "TOUCH MISSED BUTTON"
  lastActionOk = false
  terminalStatus(lastMeta, lastEnv, detectMonitors())
  return false
end

return M
