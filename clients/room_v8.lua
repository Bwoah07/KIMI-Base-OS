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

local cfg, monitors, targets, lastEnv, lastMeta = nil, {}, {}, nil, nil

local function upper(v) return tostring(v or ""):upper() end
local function nice(v)
  return upper(tostring(v or ""):gsub("minecraft:", ""):gsub("[_%-]", " "):gsub("(%l)(%u)", "%1 %2"))
end
local function gameTime()
  local ok, t = pcall(os.time, "ingame")
  t = ok and tonumber(t) or 0
  local h = math.floor(t % 24)
  local m = math.floor(((t % 24) - h) * 60)
  return string.format("%02d:%02d", h, m)
end
local function computerName()
  local label = type(os.getComputerLabel) == "function" and os.getComputerLabel() or nil
  if label and tostring(label):match("%S") and not tostring(label):match("^KIMI[%s%-]?%d+$") then return upper(label) end
  local n = cfg and cfg.name
  if n and tostring(n):match("%S") and not tostring(n):match("^KIMI[%s%-]?%d+$") then return upper(n) end
  return "ROOM PANEL"
end

local function detectMonitors()
  local out = {}
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.hasType(name, "monitor") then
      local mon = peripheral.wrap(name)
      if mon then
        local scale = 1.0
        pcall(mon.setTextScale, scale)
        local ok, w, h = pcall(mon.getSize)
        if ok and tonumber(w) and tonumber(h) then
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
  text = tostring(text or "")
  x = math.max(1, x)
  e.mon.setCursorPos(x, y)
  e.mon.setTextColor(fg or C.text)
  e.mon.setBackgroundColor(bg or C.bg)
  e.mon.write(text:sub(1, math.max(0, e.w - x + 1)))
  e.mon.setBackgroundColor(C.bg)
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
  if y >= 1 and y <= e.h then put(e, 2, y, string.rep("-", math.max(0, e.w - 2)), C.panel) end
end
local function prep(e)
  pcall(e.mon.setTextScale, e.scale)
  e.mon.setBackgroundColor(C.bg)
  e.mon.setTextColor(C.text)
  e.mon.clear()
  targets[e.name] = {}
end
local function register(e, t)
  targets[e.name] = targets[e.name] or {}
  targets[e.name][#targets[e.name] + 1] = t
end
local function actionButton(e, name, y, label, data, color)
  local x1, x2 = 3, e.w - 2
  local hitY1, hitY2 = math.max(1, y - 1), math.min(e.h, y + 1)
  fill(e, x1, y, x2, y, color or C.action)
  center(e, y, label, C.text, color or C.action, x1 + 2, x2 - 2)
  register(e, { name = name, x1 = x1, y1 = hitY1, x2 = x2, y2 = hitY2, data = data, label = label })
end
local function smallButton(e, name, x1, y, x2, label, data)
  fill(e, x1, y, x2, y, C.panel)
  center(e, y, label, C.text, C.panel, x1 + 1, x2 - 1)
  register(e, { name = name, x1 = x1, y1 = y, x2 = x2, y2 = y, data = data, label = label })
end

local function localState(meta) return meta and meta.localState or {} end
local function localDoors(meta)
  return localState(meta).doors and localState(meta).doors.localDoors or {}
end
local function candidates(meta)
  local raw = localState(meta).doors and localState(meta).doors.candidates or {}
  local dedicated, fallback = {}, {}
  for _, c in ipairs(raw) do
    if c.localConfigured ~= true then
      if tostring(c.target) == "computer" then fallback[#fallback + 1] = c else dedicated[#dedicated + 1] = c end
    end
  end
  return #dedicated > 0 and dedicated or fallback
end
local function attachmentState(meta) return localState(meta).attachments or {} end
local function sensorInfo(meta)
  local a = attachmentState(meta)
  local sensors = a.sensors or {}
  local diag = a.diagnostics or {}
  if #sensors > 0 then return true, sensors[1], tostring(#sensors) .. " LINKED" end
  if diag.onlyInfrastructure then return false, nil, "OFFLINE" end
  if tonumber(a.dataCount or 0) > 0 then return false, nil, "UNKNOWN" end
  return false, nil, "OFFLINE"
end
local function sensorMetric(sensor)
  local m = sensor and sensor.metrics or {}
  local order = {
    {"temperature", "TEMP"}, {"onlinePlayers", "PLAYERS"}, {"biome", "BIOME"},
    {"dimension", "DIMENSION"}, {"radiationRaw", "RADIATION"}, {"humidity", "HUMIDITY"},
    {"pressure", "PRESSURE"}, {"maxScanRadius", "RANGE"}
  }
  for _, p in ipairs(order) do if m[p[1]] ~= nil then return p[2], nice(m[p[1]]) end end
  return "STATUS", upper(sensor and sensor.summary or "ONLINE")
end
local function sensorTitle(sensor)
  local t = nice(sensor and sensor.type or "SENSOR")
  if t:find("ENVIRONMENT", 1, true) then return "ENVIRONMENT" end
  if t:find("PLAYER", 1, true) then return "PLAYER DETECTOR" end
  if t:find("GEO", 1, true) then return "GEO SCANNER" end
  return t
end

local function header(e)
  put(e, 2, 1, "ROOM", C.text)
  put(e, math.max(2, e.w - 6), 1, gameTime(), C.dim)
  put(e, 2, 2, computerName(), C.dim)
  rule(e, 3)
end
local function statusRow(e, meta)
  local linked, _, sensorText = sensorInfo(meta)
  put(e, 2, 5, "BASE", C.dim)
  put(e, 7, 5, meta and meta.connected == false and "OFFLINE" or "ONLINE", meta and meta.connected == false and C.warn or C.good)
  local label = "SENSOR " .. sensorText
  put(e, math.max(2, e.w - #label - 1), 5, label, linked and C.good or C.warn)
end

local function drawSensorFooter(e, meta)
  local linked, sensor = sensorInfo(meta)
  local y = e.h - 3
  rule(e, y)
  if linked then
    local k, v = sensorMetric(sensor)
    put(e, 2, y + 1, sensorTitle(sensor), C.text)
    put(e, 2, y + 2, k .. "  " .. v, C.good)
  else
    put(e, 2, y + 1, "SENSOR OFFLINE", C.warn)
    put(e, 2, y + 2, "WIRE DETECTOR VIA MODEM", C.dim)
  end
end

local function renderDoor(e, meta)
  local doors = localDoors(meta)
  if #doors == 0 then return false end
  local d = doors[1]
  local mode = tostring(d.mode or "hold")
  local state = d.online == false and "OFFLINE" or (mode == "pulse" and "PULSE" or (d.open and "OPEN" or "CLOSED"))
  center(e, 8, upper(d.name or "LOCAL DOOR"), C.dim, nil, 2, e.w - 1)
  center(e, 10, state, d.online == false and C.bad or (d.open and C.good or C.text), nil, 2, e.w - 1)
  local label = mode == "pulse" and "TRIGGER DOOR" or (d.open and "CLOSE DOOR" or "OPEN DOOR")
  actionButton(e, "door_toggle", 13, label, { _source = tostring(os.getComputerID()), target = d.target, side = d.side, id = d.id }, d.open and C.good or C.action)
  if e.h >= 21 then
    smallButton(e, "door_mode", 3, 16, math.min(e.w - 2, 18), "MODE " .. upper(mode), { target = d.target, side = d.side, mode = mode })
  end
  drawSensorFooter(e, meta)
  return true
end

local function groupCandidates(list)
  local order, groups = {}, {}
  for _, c in ipairs(list or {}) do
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

local function renderSetup(e, meta)
  local list = candidates(meta)
  center(e, 8, "SET UP DOOR", C.text, nil, 2, e.w - 1)
  if #list == 0 then
    center(e, 11, "NO ACTUATOR FOUND", C.warn, nil, 2, e.w - 1)
    center(e, 13, "CONNECT REDSTONE / RELAY", C.dim, nil, 2, e.w - 1)
    drawSensorFooter(e, meta)
    return
  end
  local order, groups = groupCandidates(list)
  local chosen = groups[order[1]] or {}
  local first = chosen[1]
  center(e, 10, first and nice(first.type or first.controller) or "CONTROLLER", C.dim, nil, 2, e.w - 1)
  if first and #chosen == 1 and not first.side then
    actionButton(e, "door_register", 13, "USE THIS ACTUATOR", { target = first.target, side = first.side, name = computerName() })
  else
    center(e, 12, "TAP OUTPUT THAT OPENS DOOR", C.dim, nil, 2, e.w - 1)
    local cols, gap = 3, 1
    local left, right = 3, e.w - 2
    local cell = math.floor((right - left + 1 - gap * (cols - 1)) / cols)
    for i, c in ipairs(chosen) do
      if i > 6 then break end
      local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
      local x1 = left + col * (cell + gap)
      local x2 = col == 2 and right or x1 + cell - 1
      local y = 15 + row * 3
      smallButton(e, "door_register", x1, y, x2, nice(c.side or c.label or "OUTPUT"), { target = c.target, side = c.side, name = computerName() })
    end
  end
  drawSensorFooter(e, meta)
end

local function renderRoom(e, env, meta)
  prep(e); header(e); statusRow(e, meta)
  if not renderDoor(e, meta) then renderSetup(e, meta) end
end

local function renderSensorScreen(e, meta)
  prep(e); header(e); statusRow(e, meta)
  local linked, sensor = sensorInfo(meta)
  center(e, 8, "LOCAL SENSOR", C.dim, nil, 2, e.w - 1)
  if linked then
    center(e, 11, sensorTitle(sensor), C.text, nil, 2, e.w - 1)
    local k, v = sensorMetric(sensor)
    center(e, 14, k .. "  " .. v, C.good, nil, 2, e.w - 1)
  else
    center(e, 11, "SENSOR OFFLINE", C.warn, nil, 2, e.w - 1)
    center(e, 14, "WIRE DETECTOR VIA MODEM", C.dim, nil, 2, e.w - 1)
  end
end

local function renderStatusScreen(e, meta)
  prep(e); header(e)
  center(e, math.max(6, math.floor(e.h / 2) - 1), gameTime(), C.text, nil, 2, e.w - 1)
  center(e, math.max(8, math.floor(e.h / 2) + 2), meta and meta.connected == false and "MAIN BASE OFFLINE" or "MAIN BASE ONLINE", meta and meta.connected == false and C.warn or C.good, nil, 2, e.w - 1)
end

local function renderAll(env, meta)
  monitors = detectMonitors()
  for i, e in ipairs(monitors) do
    if i == 1 then renderRoom(e, env, meta)
    elseif i == 2 then renderSensorScreen(e, meta)
    else renderStatusScreen(e, meta) end
  end
end

function M.init(newCfg)
  cfg = newCfg or {}
  monitors = detectMonitors()
end
function M.onPeripheralChange()
  monitors = detectMonitors()
  if lastEnv then renderAll(lastEnv, lastMeta) end
end
function M.render(env, meta)
  lastEnv, lastMeta = env, meta
  renderAll(env, meta)
end
function M.handleEvent(e, env, action)
  if e[1] ~= "monitor_touch" then return false end
  local name, x, y = e[2], tonumber(e[3]), tonumber(e[4])
  if not name or not x or not y then return false end
  for _, t in ipairs(targets[name] or {}) do
    if x >= t.x1 and x <= t.x2 and y >= t.y1 and y <= t.y2 then
      local ok, result = true, nil
      if t.name == "door_toggle" then
        ok, result = action and action("__local_doors", "toggle", t.data)
      elseif t.name == "door_register" then
        ok, result = action and action("__local_doors", "register_local", t.data)
      elseif t.name == "door_mode" then
        local nextMode = t.data.mode == "hold" and "invert" or (t.data.mode == "invert" and "pulse" or "hold")
        ok, result = action and action("__local_doors", "configure_local", { target = t.data.target, side = t.data.side, mode = nextMode })
      end
      if ok ~= false then
        if lastMeta and lastMeta.localState then
          -- The client command path refreshes localState before returning; rendering here
          -- gives immediate visual feedback without waiting for the next network poll.
        end
      end
      renderAll(lastEnv or env, lastMeta)
      return true
    end
  end
  return false
end

return M
