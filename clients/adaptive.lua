local Adaptive = {}

local function copy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end

local function count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

local function upper(v)
    return tostring(v or ""):upper()
end

local function clamp(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function gameTime()
    local ok, value = pcall(os.time, "ingame")
    local t = ok and tonumber(value) or 0
    local h = math.floor(t % 24)
    local m = math.floor(((t % 24) - h) * 60)
    return string.format("%02d:%02d", h, m)
end

local function gameDay()
    local ok, value = pcall(os.day, "ingame")
    return ok and tostring(value) or "?"
end

local function fmtNumber(value)
    local n = tonumber(value)
    if not n then return "?" end
    local a = math.abs(n)
    if a >= 1e15 then return string.format("%.1fP", n / 1e15) end
    if a >= 1e12 then return string.format("%.1fT", n / 1e12) end
    if a >= 1e9 then return string.format("%.1fG", n / 1e9) end
    if a >= 1e6 then return string.format("%.1fM", n / 1e6) end
    if a >= 1e3 then return string.format("%.1fK", n / 1e3) end
    return tostring(math.floor(n + 0.5))
end

local function fmtFE(value, rate)
    local s = fmtNumber(value)
    if s == "?" then return s end
    return s .. " FE" .. (rate and "/t" or "")
end

local function pct(power)
    local p = tonumber(power and power.filledPercentage)
    if p then
        if p <= 1 then p = p * 100 end
        return clamp(p, 0, 100)
    end
    local stored = tonumber(power and power.stored)
    local capacity = tonumber(power and power.capacity)
    if stored and capacity and capacity > 0 then return clamp(stored / capacity * 100, 0, 100) end
    return 0
end

local function friendlyDefaultName()
    local label = type(os.getComputerLabel) == "function" and os.getComputerLabel() or nil
    if label and tostring(label):match("%S") then return tostring(label) end
    return "KIMI " .. tostring(os.getComputerID())
end

function Adaptive.create(options)
    options = options or {}
    local mode = options.mode or "wall"
    local cfg = nil
    local monitors = {}
    local targets = {}
    local manualViews = {}
    local pages = {}
    local toast = {}
    local lastEnvelope, lastMeta

    local C = {
        bg = colors.black,
        panel = colors.gray,
        text = colors.white,
        muted = colors.lightGray,
        line = colors.gray,
        good = colors.lime,
        warn = colors.orange,
        bad = colors.red,
        action = colors.blue
    }

    local function detectMonitors()
        local out = {}
        for _, name in ipairs(peripheral.getNames()) do
            if peripheral.hasType(name, "monitor") then
                local mon = peripheral.wrap(name)
                if mon then
                    pcall(mon.setTextScale, 0.5)
                    local ok, w, h = pcall(mon.getSize)
                    if ok and tonumber(w) and tonumber(h) then
                        w, h = tonumber(w), tonumber(h)
                        out[#out + 1] = {
                            name = name, mon = mon, w = w, h = h,
                            area = w * h,
                            class = w >= 70 and "large" or (w >= 42 and "medium" or "small")
                        }
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

    local function prep(entry)
        local mon = entry.mon
        pcall(mon.setTextScale, 0.5)
        mon.setBackgroundColor(C.bg)
        mon.setTextColor(C.text)
        mon.clear()
        mon.setCursorPos(1, 1)
    end

    local function put(entry, x, y, text, fg, bg)
        if y < 1 or y > entry.h or x > entry.w then return end
        x = math.max(1, x)
        text = tostring(text or "")
        local mon = entry.mon
        mon.setCursorPos(x, y)
        mon.setTextColor(fg or C.text)
        mon.setBackgroundColor(bg or C.bg)
        mon.write(text:sub(1, math.max(0, entry.w - x + 1)))
        mon.setBackgroundColor(C.bg)
    end

    local function fill(entry, x1, y1, x2, y2, bg)
        x1, x2 = math.max(1, x1), math.min(entry.w, x2)
        y1, y2 = math.max(1, y1), math.min(entry.h, y2)
        if x2 < x1 or y2 < y1 then return end
        for y = y1, y2 do put(entry, x1, y, string.rep(" ", x2 - x1 + 1), C.text, bg) end
    end

    local function center(entry, y, text, fg, bg, x1, x2)
        x1, x2 = x1 or 1, x2 or entry.w
        local width = math.max(1, x2 - x1 + 1)
        text = tostring(text or "")
        if #text > width then text = text:sub(1, width) end
        put(entry, x1 + math.max(0, math.floor((width - #text) / 2)), y, text, fg, bg)
    end

    local function rule(entry, y, x1, x2)
        x1, x2 = x1 or 2, x2 or entry.w - 1
        if x2 >= x1 then put(entry, x1, y, string.rep("-", x2 - x1 + 1), C.line) end
    end

    local function header(entry, title, right)
        fill(entry, 1, 1, entry.w, 2, C.panel)
        put(entry, 2, 1, upper(title), C.text, C.panel)
        put(entry, 2, 2, upper((cfg and cfg.name) or friendlyDefaultName()), C.muted, C.panel)
        if right then put(entry, math.max(2, entry.w - #tostring(right)), 1, tostring(right), C.text, C.panel) end
        local t = toast[entry.name]
        if t and t.untilAt > os.epoch("utc") then
            fill(entry, 1, 3, entry.w, 3, C.bg)
            center(entry, 3, t.text, t.color)
        else
            toast[entry.name] = nil
        end
    end

    local function line(entry, y, label, value, color)
        if y > entry.h then return end
        label, value = tostring(label or ""), tostring(value or "")
        local left = label ~= "" and (upper(label) .. " ") or ""
        put(entry, 2, y, left, C.muted)
        put(entry, 2 + #left, y, value, color or C.text)
    end

    local function register(entry, target)
        targets[entry.name] = targets[entry.name] or {}
        targets[entry.name][#targets[entry.name] + 1] = target
    end

    local function button(entry, name, x1, y1, x2, y2, text, enabled, data, bg, fg)
        x1, x2 = math.max(1, x1), math.min(entry.w, x2)
        y1, y2 = math.max(1, y1), math.min(entry.h, y2)
        if x2 < x1 or y2 < y1 then return end
        enabled = enabled ~= false
        bg = enabled and (bg or C.action) or C.panel
        fg = enabled and (fg or C.text) or C.muted
        fill(entry, x1, y1, x2, y2, bg)
        center(entry, math.floor((y1 + y2) / 2), text, fg, bg, x1, x2)
        register(entry, { name = name, x1 = x1, y1 = y1, x2 = x2, y2 = y2, enabled = enabled, data = data, label = text })
    end

    local function stateOf(envelope)
        return envelope and envelope.state or {}
    end

    local function sourceName(source, envelope)
        source = tostring(source or "server")
        if source == "server" then return "MAIN SERVER" end
        local state = stateOf(envelope)
        local item = (state.sources and state.sources[source]) or (state.fleet and (state.fleet[source] or state.fleet[tonumber(source)]))
        local name = item and item.name
        if name and tostring(name):match("%S") then return tostring(name) end
        return "COMPUTER " .. source
    end

    local function localSource(meta)
        if meta and meta.localServer then return "server" end
        return tostring(os.getComputerID())
    end

    local function localDoors(envelope, meta)
        local wanted = localSource(meta)
        local out = {}
        local doors = stateOf(envelope).doors and stateOf(envelope).doors.doors or {}
        for _, door in ipairs(doors) do
            if tostring(door._source or door.source or "server") == wanted then out[#out + 1] = door end
        end
        return out
    end

    local function globalSensors(envelope)
        local state = stateOf(envelope)
        local out = {}
        for _, sensor in ipairs(state.attachments and state.attachments.sensors or {}) do out[#out + 1] = sensor end
        if #out == 0 and state.environment then
            local env = state.environment
            if env._status ~= "offline" then
                out[#out + 1] = {
                    name = env.sensor or "environment",
                    type = "environment_detector",
                    summary = tostring(env.weather or "") .. "  " .. tostring(env.biome or ""),
                    metrics = { weather = env.weather, biome = env.biome, dimension = env.dimension, blockLight = env.blockLight, skyLight = env.skyLight },
                    _source = env._source or "server"
                }
            end
        end
        return out
    end

    local function localSensors(meta)
        local localState = meta and meta.localState or {}
        return localState.attachments and localState.attachments.sensors or {}
    end

    local function powerState(envelope, meta, preferLocal)
        if preferLocal and meta and meta.localState and meta.localState.power and (meta.localState.power.onlineSources or 0) > 0 then return meta.localState.power end
        return stateOf(envelope).power or {}
    end

    local function capabilities(envelope, meta)
        local state = stateOf(envelope)
        local ld = localDoors(envelope, meta)
        local ls = localSensors(meta)
        local gs = globalSensors(envelope)
        local lp = meta and meta.localState and meta.localState.power or nil
        return {
            localDoors = ld,
            localSensors = ls,
            sensors = gs,
            doors = state.doors and state.doors.doors or {},
            candidates = state.doors and state.doors.candidates or {},
            power = state.power or {},
            localPower = lp,
            hasPower = (state.power and tonumber(state.power.onlineSources) or 0) > 0,
            hasLocalPower = lp and (tonumber(lp.onlineSources) or 0) > 0,
            hasSensors = #gs > 0,
            hasLocalSensors = #ls > 0
        }
    end

    local function unique(list)
        local seen, out = {}, {}
        for _, value in ipairs(list) do
            if value and not seen[value] then seen[value] = true; out[#out + 1] = value end
        end
        return out
    end

    local function autoViews(envelope, meta)
        local cap = capabilities(envelope, meta)
        local views = {}
        if mode == "admin" then
            views = { "overview" }
            if #cap.doors > 0 then views[#views + 1] = "doors" end
            if cap.hasPower then views[#views + 1] = "power" end
            if cap.hasSensors then views[#views + 1] = "sensors" end
            views[#views + 1] = "fleet"
            views[#views + 1] = "status"
        else
            if #cap.localDoors > 0 then views[#views + 1] = "local_doors" end
            if cap.hasLocalPower then views[#views + 1] = "power_local" end
            if cap.hasLocalSensors then views[#views + 1] = "sensors_local" end
            views[#views + 1] = "status"
            if cap.hasPower then views[#views + 1] = "power" end
            if cap.hasSensors then views[#views + 1] = "sensors" end
            if #cap.doors > 0 then views[#views + 1] = "doors_readonly" end
        end
        return unique(views)
    end

    local function plan(envelope, meta)
        local available = autoViews(envelope, meta)
        local out = {}
        for index, entry in ipairs(monitors) do
            local manual = manualViews[entry.name]
            if manual then
                out[entry.name] = manual
            else
                local view = available[((index - 1) % math.max(1, #available)) + 1] or "status"
                if entry.class == "small" and view == "overview" then view = "status" end
                if entry.class == "small" and view == "fleet" then view = "status" end
                out[entry.name] = view
            end
        end
        return out
    end

    local function weatherLine(envelope)
        local env = stateOf(envelope).environment
        if not env or env._status == "offline" then return "NO WEATHER SENSOR", C.warn end
        local text = tostring(env.weather or "UNKNOWN")
        if env.biome and env.biome ~= "UNKNOWN" then text = text .. "  " .. tostring(env.biome):gsub("minecraft:", "") end
        return upper(text), (env.weather == "THUNDER" and C.bad or (env.weather == "RAINING" and C.warn or C.good))
    end

    local function bigTime(entry, y)
        local value = gameTime()
        local scale = entry.w >= 52 and 3 or (entry.w >= 32 and 2 or 1)
        local width = #value * scale
        local x = math.max(2, math.floor((entry.w - width) / 2))
        put(entry, x, y, value, C.text)
        if scale > 1 then
            for row = 1, scale - 1 do put(entry, x, y + row, value, C.text) end
        end
    end

    local function footer(entry, text)
        fill(entry, 1, entry.h, entry.w, entry.h, C.panel)
        center(entry, entry.h, text, C.muted, C.panel)
    end

    local function nav(entry)
        if mode ~= "admin" or entry.w < 38 or entry.h < 16 then return 0 end
        local items = { {"nav_auto", "AUTO"}, {"nav_overview", "HOME"}, {"nav_doors", "DOORS"}, {"nav_power", "POWER"}, {"nav_sensors", "SENSORS"} }
        local cell = math.floor(entry.w / #items)
        local y = entry.h - 1
        for i, item in ipairs(items) do
            local x1 = (i - 1) * cell + 1
            local x2 = i == #items and entry.w or i * cell
            button(entry, item[1], x1, y, x2, entry.h, item[2], true, nil, C.panel, C.text)
        end
        return 2
    end

    local function card(entry, x1, y1, x2, y2, title, value, color, sub)
        fill(entry, x1, y1, x2, y2, C.panel)
        put(entry, x1 + 1, y1, upper(title), C.muted, C.panel)
        center(entry, y1 + math.max(1, math.floor((y2 - y1) / 2)), value, color or C.text, C.panel, x1, x2)
        if sub and y2 - y1 >= 3 then center(entry, y2, sub, C.muted, C.panel, x1, x2) end
    end

    local function renderStatus(entry, envelope, meta)
        prep(entry); header(entry, "BASE STATUS", gameDay())
        local weather, wc = weatherLine(envelope)
        bigTime(entry, entry.h >= 18 and 5 or 4)
        local y = entry.h >= 18 and 10 or 7
        center(entry, y, weather, wc)
        local state = stateOf(envelope)
        local online, total = 0, 0
        for _, machine in pairs(state.fleet or {}) do total = total + 1; if machine.online ~= false then online = online + 1 end end
        center(entry, y + 2, tostring(#globalSensors(envelope)) .. " SENSORS   " .. tostring(online) .. "/" .. tostring(total) .. " COMPUTERS", C.muted)
        footer(entry, meta and meta.connected == false and "SEARCHING FOR KIMI SERVER" or "KIMI ONLINE")
    end

    local function renderOverview(entry, envelope, meta)
        prep(entry); header(entry, "COMMAND CENTER", gameTime())
        local state = stateOf(envelope)
        local doors = state.doors and state.doors.doors or {}
        local open, offline = 0, 0
        for _, door in ipairs(doors) do if door.online == false then offline = offline + 1 elseif door.open then open = open + 1 end end
        local sensors = globalSensors(envelope)
        local power = state.power or {}
        local p = pct(power)
        local online, total = 0, 0
        for _, machine in pairs(state.fleet or {}) do total = total + 1; if machine.online ~= false then online = online + 1 end end
        local top = 5
        local bottom = entry.h - (mode == "admin" and 3 or 1)
        local mid = math.floor(entry.w / 2)
        local rowH = math.max(4, math.floor((bottom - top - 1) / 2))
        card(entry, 2, top, mid - 1, top + rowH, "Doors", tostring(open) .. " OPEN / " .. tostring(#doors) .. " TOTAL", offline > 0 and C.warn or C.good, offline > 0 and (tostring(offline) .. " OFFLINE") or "ALL REACHABLE")
        card(entry, mid + 1, top, entry.w - 1, top + rowH, "Power", string.format("%.1f%%", p), p >= 25 and C.good or C.warn, fmtFE(power.input, true) .. " IN")
        local y2 = top + rowH + 2
        card(entry, 2, y2, mid - 1, bottom, "Sensors", tostring(#sensors) .. " LIVE", #sensors > 0 and C.good or C.warn, #sensors > 0 and "TELEMETRY ACTIVE" or "NO SENSOR DATA")
        card(entry, mid + 1, y2, entry.w - 1, bottom, "Fleet", tostring(online) .. "/" .. tostring(total) .. " ONLINE", online == total and C.good or C.warn, upper((state.update and state.update.syncResult) or "AUTO SYNC"))
        nav(entry)
    end

    local function displayDoorName(door, envelope)
        local name = tostring(door.name or "")
        if name == "" or name:match("^DOOR%s+%d+") then
            local src = sourceName(door._source or door.source, envelope)
            if not src:match("^COMPUTER%s+%d+$") and src ~= "MAIN SERVER" then return upper(src) end
            local side = tostring(door.side or "")
            if side ~= "" then return upper(side .. " DOOR") end
            return "DOOR " .. tostring(door.id or "")
        end
        return upper(name)
    end

    local function renderDoorTiles(entry, envelope, meta, localOnly, readonly)
        prep(entry)
        local all = localOnly and localDoors(envelope, meta) or (stateOf(envelope).doors and stateOf(envelope).doors.doors or {})
        header(entry, localOnly and "LOCAL DOORS" or "DOOR CONTROL", gameTime())
        local weather, wc = weatherLine(envelope)
        put(entry, 2, 4, weather, wc)
        if #all == 0 then
            center(entry, math.max(7, math.floor(entry.h / 2)), localOnly and "NO LOCAL DOOR IS CONFIGURED" or "NO DOORS CONFIGURED", C.warn)
            center(entry, math.max(9, math.floor(entry.h / 2) + 2), localOnly and "ADD THIS COMPUTER'S OUTPUT ON THE COMMAND CENTER" or "OPEN SETUP TO ADD A REDSTONE OUTPUT", C.muted)
            if mode == "admin" and not readonly then button(entry, "door_setup", 2, entry.h - 4, entry.w - 1, entry.h - 2, "DOOR SETUP", true, nil, C.action) end
            nav(entry)
            return
        end
        local navRows = mode == "admin" and 2 or 0
        local top, bottom = 6, entry.h - navRows - 1
        local cols = entry.w >= 70 and 3 or (entry.w >= 36 and 2 or 1)
        local gap = 1
        local cellW = math.floor((entry.w - 2 - (cols - 1) * gap) / cols)
        local rows = math.max(1, math.ceil(#all / cols))
        local cellH = math.max(3, math.floor((bottom - top + 1 - (rows - 1)) / rows))
        for i, door in ipairs(all) do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local x1 = 2 + col * (cellW + gap)
            local x2 = math.min(entry.w - 1, x1 + cellW - 1)
            local y1 = top + row * (cellH + 1)
            local y2 = math.min(bottom, y1 + cellH - 1)
            if y1 <= bottom then
                local bg = door.online == false and C.panel or (door.open and C.good or C.action)
                local stateText = door.online == false and "OFFLINE" or (door.open and "OPEN" or "CLOSED")
                fill(entry, x1, y1, x2, y2, bg)
                center(entry, y1 + 1, displayDoorName(door, envelope), door.open and colors.black or C.text, bg, x1, x2)
                center(entry, math.min(y2, y1 + 2), stateText, door.open and colors.black or C.text, bg, x1, x2)
                if not readonly then
                    register(entry, { name = localOnly and "door_toggle_local" or "door_toggle", x1 = x1, y1 = y1, x2 = x2, y2 = y2, enabled = door.online ~= false, label = stateText, data = { _source = door._source or door.source, target = door.target, side = door.side, id = door.id } })
                end
            end
        end
        if mode == "admin" and not localOnly and not readonly then button(entry, "door_setup", 2, bottom, math.min(entry.w - 1, 14), bottom, "SETUP", true, nil, C.panel) end
        nav(entry)
    end

    local function renderDoorSetup(entry, envelope)
        prep(entry); header(entry, "DOOR SETUP", "SAFE OUTPUT LIST")
        local doorState = stateOf(envelope).doors or {}
        local candidates = {}
        for _, c in ipairs(doorState.candidates or {}) do if not c.configured then candidates[#candidates + 1] = c end end
        local pageSize = math.max(1, math.floor((entry.h - 8) / 3))
        local maxPage = math.max(1, math.ceil(#candidates / pageSize))
        local key = entry.name .. ":door_setup"
        pages[key] = clamp(pages[key] or 1, 1, maxPage)
        local page = pages[key]
        line(entry, 4, "AVAILABLE", tostring(#candidates) .. " UNCONFIGURED OUTPUTS", #candidates > 0 and C.good or C.warn)
        local y = 6
        local first = (page - 1) * pageSize + 1
        for i = first, math.min(#candidates, first + pageSize - 1) do
            local c = candidates[i]
            local src = sourceName(c._source, envelope)
            local target = c.target == "computer" and tostring(c.label or c.side or "OUTPUT") or tostring(c.target or "PERIPHERAL")
            button(entry, "door_register", 2, y, entry.w - 1, y + 1, upper(src .. " / " .. target), true, { key = c.key }, C.action)
            y = y + 3
        end
        local footerY = entry.h - 2
        local third = math.floor(entry.w / 3)
        button(entry, "nav_doors", 1, footerY, third, entry.h, "BACK", true, nil, C.panel)
        button(entry, "page_prev", third + 1, footerY, third * 2, entry.h, "PREV", page > 1, { key = key }, C.panel)
        button(entry, "page_next", third * 2 + 1, footerY, entry.w, entry.h, "NEXT", page < maxPage, { key = key }, C.panel)
    end

    local function metric(sensor)
        local m = sensor.metrics or {}
        local order = { "temperature", "humidity", "radiation", "onlinePlayers", "biome", "dimension", "blockLight", "skyLight", "transferRate", "storedEnergy", "energy", "fuel" }
        for _, key in ipairs(order) do
            if m[key] ~= nil then return upper(key:gsub("([A-Z])", " %1")) .. " " .. tostring(m[key]) end
        end
        return tostring(sensor.summary or "TELEMETRY ONLINE")
    end

    local function renderSensors(entry, envelope, meta, localOnly)
        prep(entry); header(entry, localOnly and "LOCAL SENSORS" or "SENSORS", gameTime())
        local list = localOnly and localSensors(meta) or globalSensors(envelope)
        line(entry, 4, "LIVE", tostring(#list) .. " SENSOR" .. (#list == 1 and "" or "S"), #list > 0 and C.good or C.warn)
        if #list == 0 then
            center(entry, 8, "NO SENSOR DATA RECEIVED", C.warn)
            center(entry, 10, "CHECK ATTACHMENT + NODE STATUS", C.muted)
            return
        end
        local perPage = math.max(1, math.floor((entry.h - 7) / 3))
        local maxPage = math.max(1, math.ceil(#list / perPage))
        local key = entry.name .. ":sensors:" .. tostring(localOnly)
        pages[key] = clamp(pages[key] or 1, 1, maxPage)
        local page = pages[key]
        local y = 6
        local first = (page - 1) * perPage + 1
        for i = first, math.min(#list, first + perPage - 1) do
            local sensor = list[i]
            local src = localOnly and "LOCAL" or sourceName(sensor._source, envelope)
            put(entry, 2, y, upper(sensor.name or sensor.type or ("SENSOR " .. i)), C.text)
            put(entry, 2, y + 1, metric(sensor), C.good)
            put(entry, 2, y + 2, upper(src .. " / " .. tostring(sensor.type or "sensor")), C.muted)
            y = y + 3
        end
        if maxPage > 1 then footer(entry, tostring(page) .. "/" .. tostring(maxPage) .. "  TOUCH LEFT/RIGHT EDGE TO PAGE") end
    end

    local function renderPower(entry, envelope, meta, localOnly)
        prep(entry); header(entry, localOnly and "LOCAL POWER" or "POWER", gameTime())
        local power = powerState(envelope, meta, localOnly)
        local sources = tonumber(power.onlineSources) or 0
        if sources <= 0 then center(entry, 8, "NO POWER TELEMETRY", C.warn); return end
        local percent = pct(power)
        local color = percent >= 60 and C.good or (percent >= 25 and C.warn or C.bad)
        center(entry, 5, string.format("%.1f%%", percent), color)
        local barX1, barX2 = 3, entry.w - 2
        local filled = math.floor((barX2 - barX1 + 1) * percent / 100)
        if filled > 0 then fill(entry, barX1, 7, barX1 + filled - 1, 8, color) end
        if barX1 + filled <= barX2 then fill(entry, barX1 + filled, 7, barX2, 8, C.panel) end
        line(entry, 10, "STORED", fmtFE(power.stored, false))
        line(entry, 11, "CAPACITY", fmtFE(power.capacity, false))
        line(entry, 13, "INPUT", fmtFE(power.input, true), C.good)
        line(entry, 14, "OUTPUT", fmtFE(power.output, true), C.warn)
        line(entry, 16, "SOURCES", tostring(sources) .. "  MATRIX " .. tostring(power.matrixCount or 0) .. "  FLUX " .. tostring(power.fluxCount or 0), C.muted)
        if entry.h >= 21 then
            local y = 18
            for i, flux in ipairs(power.fluxNetworks or {}) do
                if y > entry.h - 1 then break end
                line(entry, y, "FLUX " .. i, tostring(flux.networkName or flux.peripheral or "NETWORK") .. "  " .. fmtFE(flux.stored, false), flux.healthy == false and C.warn or C.good)
                y = y + 1
            end
        end
    end

    local function renderFleet(entry, envelope)
        prep(entry); header(entry, "KIMI FLEET", gameTime())
        local fleet = stateOf(envelope).fleet or {}
        local ids = {}
        for id in pairs(fleet) do ids[#ids + 1] = id end
        table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
        local online = 0
        for _, id in ipairs(ids) do if fleet[id].online ~= false then online = online + 1 end end
        line(entry, 4, "ONLINE", tostring(online) .. "/" .. tostring(#ids), online == #ids and C.good or C.warn)
        rule(entry, 5)
        local y = 7
        for _, id in ipairs(ids) do
            if y > entry.h - 1 then break end
            local machine = fleet[id]
            local name = machine.name or ("COMPUTER " .. tostring(id))
            put(entry, 2, y, upper(name), machine.online == false and C.bad or C.good)
            put(entry, 2, y + 1, upper(tostring(machine.role or "?") .. " / " .. tostring(machine.version or "?") .. " / ID " .. tostring(id)), C.muted)
            y = y + 2
        end
    end

    local renderers = {
        status = renderStatus,
        overview = renderOverview,
        doors = function(e, env, meta) return renderDoorTiles(e, env, meta, false, false) end,
        local_doors = function(e, env, meta) return renderDoorTiles(e, env, meta, true, false) end,
        doors_readonly = function(e, env, meta) return renderDoorTiles(e, env, meta, false, true) end,
        door_setup = renderDoorSetup,
        sensors = function(e, env, meta) return renderSensors(e, env, meta, false) end,
        sensors_local = function(e, env, meta) return renderSensors(e, env, meta, true) end,
        power = function(e, env, meta) return renderPower(e, env, meta, false) end,
        power_local = function(e, env, meta) return renderPower(e, env, meta, true) end,
        fleet = renderFleet
    }

    local function renderOne(entry, view, envelope, meta)
        targets[entry.name] = {}
        local renderer = renderers[view] or renderStatus
        renderer(entry, envelope, meta or {})
    end

    local function redraw(name)
        if not lastEnvelope then return end
        local assigned = plan(lastEnvelope, lastMeta or {})
        for _, entry in ipairs(monitors) do
            if entry.name == name then renderOne(entry, manualViews[name] or assigned[name] or "status", lastEnvelope, lastMeta or {}); return end
        end
    end

    local M = {}

    function M.init(newCfg)
        cfg = newCfg or cfg or { name = friendlyDefaultName() }
        monitors = detectMonitors()
        term.clear(); term.setCursorPos(1, 1)
        print("KIMI Adaptive Display")
        print("Profile: " .. tostring(mode))
        print("Monitors: " .. tostring(#monitors))
        for i, entry in ipairs(monitors) do print(string.format("  %d) %s %dx%d %s", i, entry.name, entry.w, entry.h, entry.class)) end
    end

    function M.render(envelope, meta)
        monitors = detectMonitors()
        lastEnvelope, lastMeta = envelope, meta or {}
        targets = {}
        local assigned = plan(envelope, lastMeta)
        for _, entry in ipairs(monitors) do renderOne(entry, assigned[entry.name] or "status", envelope, lastMeta) end
    end

    function M.onPeripheralChange()
        monitors = detectMonitors()
        targets = {}
    end

    function M.handleEvent(event, envelope, action)
        if type(event) ~= "table" or event[1] ~= "monitor_touch" then return end
        local name, x, y = event[2], tonumber(event[3]), tonumber(event[4])
        if not x or not y then return end
        for _, target in ipairs(targets[name] or {}) do
            if target.enabled and x >= target.x1 and x <= target.x2 and y >= target.y1 and y <= target.y2 then
                local entry
                for _, e in ipairs(monitors) do if e.name == name then entry = e; break end end
                if entry then
                    fill(entry, target.x1, target.y1, target.x2, target.y2, colors.white)
                    center(entry, math.floor((target.y1 + target.y2) / 2), target.label or "OK", colors.black, colors.white, target.x1, target.x2)
                end

                local n = target.name
                if n == "nav_auto" then manualViews[name] = nil
                elseif n == "nav_overview" then manualViews[name] = "overview"
                elseif n == "nav_doors" then manualViews[name] = "doors"
                elseif n == "nav_power" then manualViews[name] = "power"
                elseif n == "nav_sensors" then manualViews[name] = "sensors"
                elseif n == "door_setup" then manualViews[name] = "door_setup"
                elseif n == "page_prev" and target.data then pages[target.data.key] = math.max(1, (pages[target.data.key] or 1) - 1)
                elseif n == "page_next" and target.data then pages[target.data.key] = (pages[target.data.key] or 1) + 1
                elseif n == "door_register" and target.data then
                    toast[name] = { text = "ADDING DOOR...", color = C.good, untilAt = os.epoch("utc") + 2000 }
                    if action then action("doors", "register", target.data) end
                    manualViews[name] = "doors"
                elseif n == "door_toggle" and target.data then
                    toast[name] = { text = "DOOR COMMAND SENT", color = C.good, untilAt = os.epoch("utc") + 1500 }
                    if action then action("doors", "toggle", target.data) end
                elseif n == "door_toggle_local" and target.data then
                    toast[name] = { text = "SWITCHING LOCAL DOOR", color = C.good, untilAt = os.epoch("utc") + 1500 }
                    if action then action("__local_doors", "toggle", target.data) end
                end
                redraw(name)
                return true
            end
        end

        local view = manualViews[name]
        if view == "sensors" or view == "sensors_local" then
            local key = name .. ":sensors:" .. tostring(view == "sensors_local")
            if x <= 4 then pages[key] = math.max(1, (pages[key] or 1) - 1); redraw(name); return true end
            local entry
            for _, e in ipairs(monitors) do if e.name == name then entry = e; break end end
            if entry and x >= entry.w - 3 then pages[key] = (pages[key] or 1) + 1; redraw(name); return true end
        end
    end

    return M
end

return Adaptive
