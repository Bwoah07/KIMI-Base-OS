local M = {}

local monitors = {}
local touchTargets = {}
local monitorViews = {}
local pageState = {}
local toastState = {}
local lastEnvelope, lastMeta

local function gameTime()
    local ok, value = pcall(os.time, "ingame")
    local t = ok and tonumber(value) or 0
    local hour = math.floor(t % 24)
    local minute = math.floor(((t % 24) - hour) * 60)
    return string.format("%02d:%02d", hour, minute)
end

local function gameDay()
    local ok, value = pcall(os.day, "ingame")
    return ok and tostring(value) or "?"
end

local function getMonitors()
    local out = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "monitor") then
            local mon = peripheral.wrap(name)
            if mon then
                pcall(mon.setTextScale, 0.5)
                local w, h = mon.getSize()
                out[#out + 1] = { name = name, mon = mon, w = w, h = h, area = w * h }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.area ~= b.area then return a.area > b.area end
        return a.name < b.name
    end)
    return out
end

local function prep(mon)
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.white)
    mon.clear()
    mon.setCursorPos(1, 1)
end

local function put(mon, x, y, text, fg, bg)
    local w, h = mon.getSize()
    if y < 1 or y > h or x > w then return end
    x = math.max(1, x)
    text = tostring(text or "")
    mon.setCursorPos(x, y)
    mon.setTextColor(fg or colors.white)
    mon.setBackgroundColor(bg or colors.black)
    mon.write(text:sub(1, math.max(0, w - x + 1)))
    mon.setBackgroundColor(colors.black)
end

local function fill(mon, x1, y1, x2, y2, bg)
    local w, h = mon.getSize()
    x1, x2 = math.max(1, x1), math.min(w, x2)
    y1, y2 = math.max(1, y1), math.min(h, y2)
    if x2 < x1 or y2 < y1 then return end
    for y = y1, y2 do put(mon, x1, y, string.rep(" ", x2 - x1 + 1), colors.white, bg) end
end

local function center(mon, y, text, fg, bg, x1, x2)
    local w = select(1, mon.getSize())
    x1, x2 = x1 or 1, x2 or w
    text = tostring(text or "")
    local width = x2 - x1 + 1
    if #text > width then text = text:sub(1, width) end
    put(mon, x1 + math.max(0, math.floor((width - #text) / 2)), y, text, fg, bg)
end

local function line(mon, y, label, value, color, x, maxX)
    x = x or 2
    maxX = maxX or select(1, mon.getSize())
    label, value = tostring(label or ""), tostring(value or "")
    local text = label == "" and value or (label .. string.rep(" ", math.max(1, 11 - #label)) .. value)
    put(mon, x, y, text:sub(1, math.max(0, maxX - x + 1)), color)
end

local function divider(mon, y, x1, x2, color)
    local w = select(1, mon.getSize())
    x1, x2 = x1 or 2, x2 or w - 1
    if x2 >= x1 then put(mon, x1, y, string.rep("-", x2 - x1 + 1), color or colors.gray) end
end

local function setToast(name, text, color)
    toastState[name] = { text = text, color = color or colors.lime, untilAt = os.epoch("utc") + 2500 }
end

local function header(entry, title, right)
    local mon, w = entry.mon, entry.w
    fill(mon, 1, 1, w, 1, colors.red)
    center(mon, 1, title, colors.white, colors.red)
    if right and w >= 50 and #tostring(right) + #tostring(title) + 8 <= w then put(mon, w - #tostring(right), 1, right, colors.white, colors.red) end
    local toast = toastState[entry.name]
    if toast and toast.untilAt > os.epoch("utc") then
        fill(mon, 1, 2, w, 2, colors.black)
        center(mon, 2, toast.text, toast.color)
    else
        toastState[entry.name] = nil
    end
end

local function registerTarget(mon, target)
    local ok, name = pcall(peripheral.getName, mon)
    if not ok or not name then return end
    touchTargets[name] = touchTargets[name] or {}
    touchTargets[name][#touchTargets[name] + 1] = target
end

local function button(mon, name, x1, y1, x2, y2, text, enabled, data, style)
    local w, h = mon.getSize()
    x1, x2 = math.max(1, x1), math.min(w, x2)
    y1, y2 = math.max(1, y1), math.min(h, y2)
    if x2 < x1 or y2 < y1 then return end
    local bg = enabled == false and colors.gray or (style and style.bg or colors.red)
    local fg = enabled == false and colors.lightGray or (style and style.fg or colors.white)
    fill(mon, x1, y1, x2, y2, bg)
    local width = x2 - x1 + 1
    text = tostring(text or "")
    if #text > width - 2 then text = text:sub(1, math.max(1, width - 2)) end
    center(mon, math.floor((y1 + y2) / 2), text, fg, bg, x1, x2)
    registerTarget(mon, { name = name, x1 = x1, y1 = y1, x2 = x2, y2 = y2, enabled = enabled ~= false, data = data })
end

local function fmtNumber(value)
    local n = tonumber(value)
    if not n then return "?" end
    local a = math.abs(n)
    if a >= 1e15 then return string.format("%.2fP", n / 1e15) end
    if a >= 1e12 then return string.format("%.2fT", n / 1e12) end
    if a >= 1e9 then return string.format("%.2fG", n / 1e9) end
    if a >= 1e6 then return string.format("%.2fM", n / 1e6) end
    if a >= 1e3 then return string.format("%.2fK", n / 1e3) end
    return tostring(math.floor(n + 0.5))
end

local function fmtFE(value, rate)
    local text = fmtNumber(value)
    return text == "?" and text or text .. " FE" .. (rate and "/t" or "")
end

local function percentOf(value, stored, capacity)
    local n = tonumber(value)
    if n then
        if n <= 1 then n = n * 100 end
        return math.max(0, math.min(100, n))
    end
    stored, capacity = tonumber(stored), tonumber(capacity)
    if stored and capacity and capacity > 0 then return math.max(0, math.min(100, stored / capacity * 100)) end
    return 0
end

local function energyColor(percent)
    if percent >= 60 then return colors.lime end
    if percent >= 25 then return colors.orange end
    return colors.red
end

local function duration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if days > 0 then return string.format("%dd %02dh", days, hours) end
    if hours > 0 then return string.format("%dh %02dm", hours, minutes) end
    if minutes > 0 then return string.format("%dm %02ds", minutes, seconds % 60) end
    return tostring(seconds) .. "s"
end

local function energyStatus(power)
    local stored, capacity = tonumber(power and power.stored), tonumber(power and power.capacity)
    local input, output = tonumber(power and power.input), tonumber(power and power.output)
    local net = tonumber(power and power.net)
    if not net and input and output then net = input - output end
    if not stored or not capacity or capacity <= 0 or not net then return "DATA INCOMPLETE", colors.yellow end
    if stored >= capacity * 0.999999 and net >= -0.5 then return "FULL / HOLDING", colors.lime end
    if math.abs(net) <= 0.5 then return "STABLE / HOLDING", colors.lightGray end
    if net > 0 then return "CHARGING / FULL IN " .. duration((capacity - stored) / (net * 20)), colors.lime end
    return "DRAINING / EMPTY IN " .. duration(stored / (math.abs(net) * 20)), colors.orange
end

local function drawBar(mon, x1, y, x2, percent, color)
    if x2 - x1 < 4 then return end
    percent = math.max(0, math.min(100, tonumber(percent) or 0))
    local width = x2 - x1 + 1
    local filled = math.floor(width * percent / 100 + 0.5)
    if filled > 0 then put(mon, x1, y, string.rep(" ", filled), colors.black, color) end
    if filled < width then put(mon, x1 + filled, y, string.rep(" ", width - filled), colors.white, colors.gray) end
end

local function drawBattery(mon, x1, y1, x2, y2, percent)
    if x2 - x1 < 12 or y2 - y1 < 4 then return end
    local color = energyColor(percent)
    local innerWidth = x2 - x1 - 1
    local filled = math.floor(innerWidth * percent / 100 + 0.5)
    put(mon, x1, y1, "+" .. string.rep("-", innerWidth) .. "+", colors.lightGray)
    for y = y1 + 1, y2 - 1 do
        put(mon, x1, y, "|", colors.lightGray)
        if filled > 0 then put(mon, x1 + 1, y, string.rep(" ", filled), colors.black, color) end
        if filled < innerWidth then put(mon, x1 + 1 + filled, y, string.rep(" ", innerWidth - filled), colors.white, colors.black) end
        put(mon, x2, y, "|", colors.lightGray)
    end
    put(mon, x1, y2, "+" .. string.rep("-", innerWidth) .. "+", colors.lightGray)
    local capY = math.floor((y1 + y2) / 2)
    put(mon, x2 + 1, capY, "  ", colors.black, colors.lightGray)
    local label = string.format("%.1f%%", percent)
    center(mon, capY, label, colors.white, colors.black, x1 + 1, x2 - 1)
end

local function card(mon, x1, y1, x2, y2, title, titleColor)
    if x2 <= x1 or y2 <= y1 then return end
    fill(mon, x1, y1, x2, y1, titleColor or colors.gray)
    put(mon, x1 + 1, y1, title, colors.white, titleColor or colors.gray)
    divider(mon, y2, x1, x2, colors.gray)
end

local glyphs = {
    ["0"] = { "111", "101", "101", "101", "111" }, ["1"] = { "010", "110", "010", "010", "111" },
    ["2"] = { "111", "001", "111", "100", "111" }, ["3"] = { "111", "001", "111", "001", "111" },
    ["4"] = { "101", "101", "111", "001", "001" }, ["5"] = { "111", "100", "111", "001", "111" },
    ["6"] = { "111", "100", "111", "101", "111" }, ["7"] = { "111", "001", "010", "010", "010" },
    ["8"] = { "111", "101", "111", "101", "111" }, ["9"] = { "111", "101", "111", "001", "111" },
    [":"] = { "0", "1", "0", "1", "0" }
}

local function drawBigClock(mon, y, value, color)
    local w = select(1, mon.getSize())
    local scaleX = w >= 48 and 2 or 1
    local widths, total = {}, 0
    for index = 1, #value do
        local ch = value:sub(index, index)
        local charWidth = ch == ":" and scaleX or 3 * scaleX
        widths[index] = charWidth
        total = total + charWidth + (index < #value and scaleX or 0)
    end
    local x = math.max(2, math.floor((w - total) / 2) + 1)
    for index = 1, #value do
        local ch = value:sub(index, index)
        local rows = glyphs[ch]
        local columns = ch == ":" and 1 or 3
        for row = 1, 5 do
            for column = 1, columns do
                if rows[row]:sub(column, column) == "1" then
                    put(mon, x + (column - 1) * scaleX, y + row - 1, string.rep(" ", scaleX), colors.black, color)
                end
            end
        end
        x = x + widths[index] + (index < #value and scaleX or 0)
    end
end

local function navTop(entry)
    return entry.w >= 60 and entry.h - 2 or entry.h - 4
end

local function drawNav(entry)
    local mon, w, h = entry.mon, entry.w, entry.h
    local items = {
        { "view_overview", "HOME", colors.gray }, { "view_energy", "ENERGY", colors.red },
        { "view_sensors", "SENSORS", colors.blue }, { "view_doors", "DOORS", colors.orange },
        { "view_fleet", "FLEET", colors.gray }, { "sync_fleet", "SYNC", colors.lime }
    }
    if w >= 60 then
        local cell = math.floor(w / #items)
        for i, item in ipairs(items) do
            local x1 = (i - 1) * cell + 1
            local x2 = i == #items and w or i * cell
            local blackText = item[3] == colors.lime or item[3] == colors.orange
            button(mon, item[1], x1, h - 2, x2, h, item[2], true, nil, { bg = item[3], fg = blackText and colors.black or colors.white })
        end
    else
        local cell = math.floor(w / 3)
        for i, item in ipairs(items) do
            local row = math.floor((i - 1) / 3)
            local column = (i - 1) % 3
            local x1 = column * cell + 1
            local x2 = column == 2 and w or (column + 1) * cell
            local y1 = h - 4 + row * 2
            local blackText = item[3] == colors.lime or item[3] == colors.orange
            button(mon, item[1], x1, y1, x2, y1 + 1, item[2], true, nil, { bg = item[3], fg = blackText and colors.black or colors.white })
        end
    end
end

local function drawMatrixCard(mon, matrix, x1, y1, x2, y2, index, total)
    local percent = percentOf(matrix.filledPercentage, matrix.stored, matrix.capacity)
    local status, statusColor = energyStatus(matrix)
    card(mon, x1, y1, x2, y2, " MATRIX " .. tostring(index) .. "/" .. tostring(total) .. "  " .. tostring(matrix.peripheral or "INDUCTION PORT"), colors.green)
    if y2 - y1 < 10 then
        line(mon, y1 + 1, "STATUS", status, statusColor, x1 + 1, x2 - 1)
        drawBar(mon, x1 + 1, y1 + 2, x2 - 1, percent, energyColor(percent))
        if y1 + 3 < y2 then line(mon, y1 + 3, "STORED", string.format("%.1f%%  ", percent) .. fmtFE(matrix.stored, false), colors.white, x1 + 1, x2 - 1) end
        if y1 + 4 < y2 then line(mon, y1 + 4, "FLOW", "+" .. fmtFE(matrix.input, true) .. "  -" .. fmtFE(matrix.output, true), colors.lightGray, x1 + 1, x2 - 1) end
        return
    end
    line(mon, y1 + 2, "STATUS", status, statusColor, x1 + 1, x2 - 1)
    local batteryTop = y1 + 4
    local batteryBottom = math.min(y2 - 6, batteryTop + math.max(4, math.floor((y2 - y1) * 0.38)))
    if batteryBottom - batteryTop >= 4 then
        drawBattery(mon, x1 + 2, batteryTop, x2 - 4, batteryBottom, percent)
    else
        drawBar(mon, x1 + 2, batteryTop, x2 - 2, percent, energyColor(percent))
        center(mon, batteryTop, string.format("%.1f%%", percent), colors.white, colors.black, x1 + 2, x2 - 2)
        batteryBottom = batteryTop
    end
    local y = batteryBottom + 2
    if y < y2 then line(mon, y, "STORED", fmtFE(matrix.stored, false) .. " / " .. fmtFE(matrix.capacity, false), colors.white, x1 + 1, x2 - 1) end
    if y + 1 < y2 then line(mon, y + 1, "FLOW", "+" .. fmtFE(matrix.input, true) .. "  -" .. fmtFE(matrix.output, true), colors.white, x1 + 1, x2 - 1) end
    if y + 2 < y2 then line(mon, y + 2, "BUILD", tostring(matrix.installedCells or "?") .. " cells / " .. tostring(matrix.installedProviders or "?") .. " providers", colors.lightGray, x1 + 1, x2 - 1) end
    if y + 3 < y2 then line(mon, y + 3, "MODE", tostring(matrix.mode or "?") .. "  source " .. tostring(matrix._source or "server"), colors.lightGray, x1 + 1, x2 - 1) end
end

local function drawFluxCard(mon, flux, x1, y1, x2, y2, index, total)
    local percent = percentOf(flux.filledPercentage, flux.stored, flux.capacity)
    local titleColor = flux.healthy == false and colors.orange or colors.red
    card(mon, x1, y1, x2, y2, " FLUX " .. tostring(index) .. "/" .. tostring(total) .. "  " .. tostring(flux.networkName or "UNNAMED"), titleColor)
    line(mon, y1 + 1, "STATUS", tostring(flux.status or "ONLINE") .. " / " .. string.format("%.1f%%", percent), flux.healthy == false and colors.orange or colors.lime, x1 + 1, x2 - 1)
    drawBar(mon, x1 + 1, y1 + 2, x2 - 1, percent, energyColor(percent))
    if y1 + 3 < y2 then line(mon, y1 + 3, "STORED", fmtFE(flux.stored, false) .. " / " .. fmtFE(flux.capacity, false), colors.white, x1 + 1, x2 - 1) end
    if y1 + 4 < y2 then line(mon, y1 + 4, "FLOW", "+" .. fmtFE(flux.input, true) .. "  -" .. fmtFE(flux.output, true), colors.white, x1 + 1, x2 - 1) end
    if y1 + 5 < y2 then line(mon, y1 + 5, "DEVICES", tostring(flux.deviceCount or "?") .. "  WARN " .. tostring(flux.warningCount or 0), colors.lightGray, x1 + 1, x2 - 1) end
    if y1 + 6 < y2 then line(mon, y1 + 6, "SOURCE", tostring(flux.peripheral or "?") .. " @" .. tostring(flux._source or "server"), colors.lightGray, x1 + 1, x2 - 1) end
end

local function panelEnergy(entry, envelope)
    local mon, w = entry.mon, entry.w
    prep(mon); header(entry, "ENERGY COMMAND", gameTime())
    local power = envelope and envelope.state and envelope.state.power or {}
    local matrices, flux = power.matrices or {}, power.fluxNetworks or {}
    line(mon, 3, "ONLINE", "MATRIX " .. tostring(#matrices) .. "   FLUX " .. tostring(#flux) .. "   DETECTORS " .. tostring(#(power.energyDetectors or {})), (#matrices + #flux) > 0 and colors.lime or colors.red)
    local bottom = navTop(entry) - 1
    if #matrices == 0 and #flux == 0 then
        center(mon, math.max(7, math.floor(bottom / 2)), "NO ENERGY PERIPHERALS ONLINE", colors.red)
        center(mon, math.max(9, math.floor(bottom / 2) + 2), "Attach Matrix ports or Flux controllers to any KIMI computer", colors.lightGray)
    elseif w >= 66 and #matrices > 0 then
        local split = math.floor(w * 0.58)
        drawMatrixCard(mon, matrices[1], 2, 5, split, bottom, 1, #matrices)
        if #flux > 0 then
            local available = bottom - 4
            local shown = math.min(#flux, math.max(1, math.floor(available / 6)))
            local cardHeight = math.floor(available / shown)
            for i = 1, shown do
                local y1 = 5 + (i - 1) * cardHeight
                local y2 = i == shown and bottom or y1 + cardHeight - 1
                drawFluxCard(mon, flux[i], split + 2, y1, w - 1, y2, i, #flux)
            end
            if shown < #flux then put(mon, split + 3, bottom, "+" .. tostring(#flux - shown) .. " more Flux controller(s)", colors.yellow) end
        else
            center(mon, math.floor((5 + bottom) / 2), "NO FLUX CONTROLLERS", colors.yellow, nil, split + 2, w - 1)
        end
    else
        local top = 5
        if #matrices > 0 then
            local matrixBottom = #flux > 0 and math.floor((top + bottom) / 2) or bottom
            drawMatrixCard(mon, matrices[1], 2, top, w - 1, matrixBottom, 1, #matrices)
            top = matrixBottom + 1
        end
        if #flux > 0 and top < bottom then
            local shown = math.min(#flux, math.max(1, math.floor((bottom - top + 1) / 6)))
            local cardHeight = math.max(6, math.floor((bottom - top + 1) / shown))
            for i = 1, shown do
                local y1 = top + (i - 1) * cardHeight
                local y2 = i == shown and bottom or math.min(bottom, y1 + cardHeight - 1)
                drawFluxCard(mon, flux[i], 2, y1, w - 1, y2, i, #flux)
            end
        end
    end
    drawNav(entry)
end

local function statusColor(value)
    value = tostring(value or ""):lower()
    if value == "sunny" or value == "clear" or value == "online" or value == "up to date" or value == "current" then return colors.lime end
    if value == "thunder" or value == "offline" or value:find("failed", 1, true) then return colors.red end
    return colors.yellow
end

local function fleetSummary(fleet)
    local online, total = 0, 0
    for _, machine in pairs(fleet or {}) do total = total + 1; if machine.online ~= false then online = online + 1 end end
    return online, total
end

local function panelOverview(entry, envelope, meta)
    local mon, w = entry.mon, entry.w
    prep(mon); header(entry, "KIMI COMMAND", "SERVER #" .. tostring(meta.serverId or "?"))
    local state = envelope and envelope.state or {}
    local env, attachments = state.environment or {}, state.attachments or {}
    local online, total = fleetSummary(state.fleet)
    drawBigClock(mon, 3, gameTime(), colors.red)
    center(mon, 9, "MINECRAFT DAY " .. gameDay(), colors.lightGray)
    divider(mon, 10)
    line(mon, 11, "WEATHER", env.weather or "NO ENVIRONMENT SENSOR", statusColor(env.weather))
    line(mon, 12, "BIOME", env.biome or "UNKNOWN")
    line(mon, 13, "DIMENSION", env.dimension or "UNKNOWN")
    line(mon, 14, "MOON", env.moon or "UNKNOWN")
    line(mon, 15, "LIGHT", "sky " .. tostring(env.skyLight or "?") .. " / block " .. tostring(env.blockLight or "?"), colors.lightGray)
    divider(mon, 16)
    line(mon, 17, "FLEET", tostring(online) .. "/" .. tostring(total) .. " online", online == total and colors.lime or colors.yellow)
    line(mon, 18, "SENSORS", tostring(attachments.sensorCount or 0) .. " / " .. tostring(attachments.count or 0) .. " attachments", (attachments.sensorCount or 0) > 0 and colors.lime or colors.yellow)
    line(mon, 19, "VERSION", envelope and envelope.version or "?")
    local up = state.update or meta.update or {}
    line(mon, 20, "SYNC", tostring(up.fleetCurrent or 0) .. " current / " .. tostring(up.fleetOutdated or 0) .. " updating / " .. tostring(up.fleetOffline or 0) .. " offline", (up.fleetOutdated or 0) == 0 and colors.lime or colors.orange)
    local top = navTop(entry)
    if top >= 25 and w >= 32 then
        local mid = math.floor(w / 2)
        button(mon, "check_updates", 2, top - 3, mid - 1, top - 1, "UPDATE MAIN SERVER", true, nil, { bg = colors.red })
        button(mon, "sync_fleet", mid + 1, top - 3, w - 1, top - 1, "SYNC ALL COMPUTERS", true, nil, { bg = colors.lime, fg = colors.black })
    end
    drawNav(entry)
end

local function metricText(metrics)
    metrics = metrics or {}
    local parts = {}
    local ordered = { "temperature", "humidity", "radiation", "biome", "dimension", "onlinePlayers", "block", "transferRate", "storedEnergy", "energy", "fuel" }
    for _, key in ipairs(ordered) do
        if metrics[key] ~= nil then
            parts[#parts + 1] = key .. ":" .. tostring(metrics[key])
            if #parts >= 3 then break end
        end
    end
    return #parts > 0 and table.concat(parts, "  ") or "Telemetry methods available"
end

local function pageFor(name, key, totalPages)
    local stateKey = name .. ":" .. key
    local value = math.max(1, math.min(totalPages, tonumber(pageState[stateKey]) or 1))
    pageState[stateKey] = value
    return value, stateKey
end

local function panelSensors(entry, envelope)
    local mon, w = entry.mon, entry.w
    prep(mon)
    local sensors = envelope and envelope.state and envelope.state.attachments and envelope.state.attachments.sensors or {}
    local bottom = navTop(entry) - 1
    local pageBottom = bottom - 3
    local perPage = math.max(1, math.floor((pageBottom - 4) / 3))
    local pages = math.max(1, math.ceil(#sensors / perPage))
    local page, key = pageFor(entry.name, "sensors", pages)
    header(entry, "ALL SENSORS", tostring(#sensors) .. " FOUND  " .. tostring(page) .. "/" .. tostring(pages))
    line(mon, 3, "STATUS", #sensors > 0 and "LIVE TELEMETRY" or "WAITING FOR SENSOR", #sensors > 0 and colors.lime or colors.yellow)
    divider(mon, 4)
    local y = 5
    local first = (page - 1) * perPage + 1
    for index = first, math.min(#sensors, first + perPage - 1) do
        local sensor = sensors[index]
        put(mon, 2, y, tostring(index) .. ". " .. tostring(sensor.name) .. "  [" .. tostring(sensor.type) .. "]", colors.lime)
        put(mon, 4, y + 1, tostring(sensor.summary or "Attached") .. "  source:" .. tostring(sensor._source or "server"), colors.white)
        put(mon, 4, y + 2, metricText(sensor.metrics) .. "  methods:" .. tostring(sensor.methodCount or 0), colors.lightGray)
        y = y + 3
    end
    if #sensors == 0 then center(mon, 8, "NO SENSOR IS HIDDEN: detector / scanner / reader types appear here", colors.yellow) end
    if pages > 1 then
        local mid = math.floor(w / 2)
        button(mon, "page_prev", 2, bottom - 2, mid - 1, bottom, "PREVIOUS", page > 1, { key = key })
        button(mon, "page_next", mid + 1, bottom - 2, w - 1, bottom, "NEXT", page < pages, { key = key })
    end
    drawNav(entry)
end

local function doorTileText(door)
    return tostring(door.name or ("DOOR " .. tostring(door.id or "?"))) .. "  " .. (door.online == false and "OFFLINE" or (door.open and "OPEN" or "CLOSED"))
end

local function panelDoors(entry, envelope)
    local mon, w = entry.mon, entry.w
    prep(mon)
    local doorsState = envelope and envelope.state and envelope.state.doors or {}
    local doors = doorsState.doors or {}
    header(entry, "DOOR MANAGER", tostring(#doors) .. " CONFIGURED")
    line(mon, 3, "DISCOVERED", tostring(doorsState.candidateCount or 0) .. " output candidates (hidden until added)", colors.lightGray)
    local mid = math.floor(w / 2)
    button(mon, "door_add_view", 2, 5, mid - 1, 7, "ADD DOOR", true, nil, { bg = colors.lime, fg = colors.black })
    button(mon, "door_remove_view", mid + 1, 5, w - 1, 7, "REMOVE DOOR", #doors > 0, nil, { bg = colors.red })
    divider(mon, 8)
    local bottom = navTop(entry) - 1
    if #doors == 0 then
        center(mon, 11, "NO DOORS CONFIGURED", colors.yellow)
        center(mon, 13, "Tap ADD DOOR, then choose the exact controller and side.", colors.lightGray)
        center(mon, 14, "Raw redstone outputs are never guessed as doors.", colors.lightGray)
    else
        local columns = w >= 70 and 4 or (w >= 42 and 3 or (w >= 26 and 2 or 1))
        local gap, cellWidth = 1, math.floor((w - 3 - (columns - 1)) / columns)
        local y = 10
        for index, door in ipairs(doors) do
            local column = (index - 1) % columns
            local row = math.floor((index - 1) / columns)
            local y1 = y + row * 4
            if y1 + 2 > bottom then break end
            local x1 = 2 + column * (cellWidth + gap)
            local x2 = x1 + cellWidth - 1
            local bg = door.online == false and colors.gray or (door.open and colors.lime or colors.blue)
            button(mon, "door_toggle", x1, y1, x2, y1 + 2, doorTileText(door), door.online ~= false, {
                _source = door._source, target = door.target, side = door.side, id = door.id
            }, { bg = bg, fg = bg == colors.lime and colors.black or colors.white })
        end
    end
    drawNav(entry)
end

local function candidateLabel(candidate)
    local source = candidate._source == "server" and "MAIN" or ("#" .. tostring(candidate._source))
    local target = candidate.target == "computer" and "COMPUTER" or tostring(candidate.target or "?")
    return source .. "  " .. target .. "  " .. tostring(candidate.label or candidate.side or "DOOR"):upper()
end

local function panelDoorAdd(entry, envelope)
    local mon, w = entry.mon, entry.w
    prep(mon)
    local all = envelope and envelope.state and envelope.state.doors and envelope.state.doors.candidates or {}
    local candidates = {}
    for _, candidate in ipairs(all) do if not candidate.configured then candidates[#candidates + 1] = candidate end end
    local bottom = entry.h - 4
    local perPage = math.max(1, math.floor((bottom - 5) / 3))
    local pages = math.max(1, math.ceil(#candidates / perPage))
    local page, key = pageFor(entry.name, "door_add", pages)
    header(entry, "ADD A DOOR", tostring(#candidates) .. " AVAILABLE  " .. tostring(page) .. "/" .. tostring(pages))
    center(mon, 3, "Choose one exact redstone output or real door peripheral", colors.lightGray)
    local y = 5
    local first = (page - 1) * perPage + 1
    for index = first, math.min(#candidates, first + perPage - 1) do
        local candidate = candidates[index]
        button(mon, "door_register", 2, y, w - 1, y + 1, candidateLabel(candidate), true, { key = candidate.key }, { bg = colors.blue })
        y = y + 3
    end
    if #candidates == 0 then center(mon, 8, "No unconfigured outputs are online", colors.yellow) end
    local third = math.floor(w / 3)
    button(mon, "view_doors", 1, entry.h - 2, third, entry.h, "BACK", true, nil, { bg = colors.gray })
    button(mon, "page_prev", third + 1, entry.h - 2, third * 2, entry.h, "PREV", page > 1, { key = key })
    button(mon, "page_next", third * 2 + 1, entry.h - 2, w, entry.h, "NEXT", page < pages, { key = key })
end

local function panelDoorRemove(entry, envelope)
    local mon, w = entry.mon, entry.w
    prep(mon)
    local doors = envelope and envelope.state and envelope.state.doors and envelope.state.doors.doors or {}
    header(entry, "REMOVE A DOOR", "CONFIG ONLY")
    center(mon, 3, "This removes the KIMI button; it does not break the physical door", colors.lightGray)
    local bottom = entry.h - 4
    local perPage = math.max(1, math.floor((bottom - 5) / 3))
    local pages = math.max(1, math.ceil(#doors / perPage))
    local page, key = pageFor(entry.name, "door_remove", pages)
    local y = 5
    local first = (page - 1) * perPage + 1
    for index = first, math.min(#doors, first + perPage - 1) do
        local door = doors[index]
        button(mon, "door_remove", 2, y, w - 1, y + 1, "REMOVE " .. doorTileText(door), true, { id = door.id }, { bg = colors.red })
        y = y + 3
    end
    local third = math.floor(w / 3)
    button(mon, "view_doors", 1, entry.h - 2, third, entry.h, "BACK", true, nil, { bg = colors.gray })
    button(mon, "page_prev", third + 1, entry.h - 2, third * 2, entry.h, "PREV", page > 1, { key = key })
    button(mon, "page_next", third * 2 + 1, entry.h - 2, w, entry.h, "NEXT", page < pages, { key = key })
end

local function panelFleet(entry, envelope, meta)
    local mon, w = entry.mon, entry.w
    prep(mon); header(entry, "FLEET UPDATE CONTROL", "AUTHORITY #" .. tostring(meta.serverId or "?"))
    local state = envelope and envelope.state or {}
    local fleet, update = state.fleet or {}, state.update or meta.update or {}
    local online, total = fleetSummary(fleet)
    line(mon, 3, "SERVER OS", envelope and envelope.version or "?", colors.lime)
    line(mon, 4, "FLEET", tostring(online) .. "/" .. tostring(total) .. " online")
    line(mon, 5, "SYNC", tostring(update.fleetCurrent or 0) .. " current / " .. tostring(update.fleetOutdated or 0) .. " updating / " .. tostring(update.fleetOffline or 0) .. " offline", (update.fleetOutdated or 0) == 0 and colors.lime or colors.orange)
    line(mon, 6, "RESULT", update.syncResult or "automatic sync active", colors.lightGray)
    button(mon, "check_updates", 2, 8, math.floor(w / 2) - 1, 10, "UPDATE MAIN SERVER", true, nil, { bg = colors.red })
    button(mon, "sync_fleet", math.floor(w / 2) + 1, 8, w - 1, 10, "PUSH OS TO ALL", true, nil, { bg = colors.lime, fg = colors.black })
    divider(mon, 12)
    local ids = {}
    for id in pairs(fleet) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)
    local y, bottom = 13, navTop(entry) - 1
    for _, id in ipairs(ids) do
        if y > bottom then break end
        local machine = fleet[id]
        local onlineState = machine.online ~= false
        line(mon, y, "#" .. tostring(id), tostring(machine.role or "?") .. "  " .. tostring(machine.version or "?") .. "  " .. tostring(machine.updateStatus or (onlineState and "online" or "offline")), onlineState and colors.lime or colors.red)
        y = y + 1
    end
    drawNav(entry)
end

local function panelAttachments(entry, envelope)
    local mon = entry.mon
    prep(mon)
    local attachments = envelope and envelope.state and envelope.state.attachments or {}
    header(entry, "ALL ATTACHMENTS", tostring(attachments.count or 0) .. " FOUND")
    local categories = attachments.categories or {}
    line(mon, 3, "KINDS", "sensor " .. tostring(categories.sensor or 0) .. " / power " .. tostring(categories.power or 0) .. " / storage " .. tostring(categories.storage or 0) .. " / control " .. tostring(categories.control or 0))
    divider(mon, 4)
    local y, bottom = 5, navTop(entry) - 1
    for _, device in ipairs(attachments.devices or {}) do
        if y + 1 > bottom then break end
        put(mon, 2, y, tostring(device.name) .. "  [" .. tostring(device.type) .. "]", device.online == false and colors.red or colors.lime)
        put(mon, 4, y + 1, tostring(device.summary or "Attached") .. "  source:" .. tostring(device._source or "server") .. "  methods:" .. tostring(device.methodCount or 0), colors.lightGray)
        y = y + 2
    end
    drawNav(entry)
end

local renderers = {
    energy = panelEnergy, overview = panelOverview, sensors = panelSensors, doors = panelDoors,
    door_add = panelDoorAdd, door_remove = panelDoorRemove, fleet = panelFleet, attachments = panelAttachments
}

local defaults = { "energy", "overview", "sensors", "doors", "fleet", "attachments" }

local function renderOne(entry, envelope, meta, index)
    touchTargets[entry.name] = {}
    local view = monitorViews[entry.name] or defaults[((index - 1) % #defaults) + 1]
    local renderer = renderers[view] or panelEnergy
    renderer(entry, envelope, meta or {})
end

function M.init()
    monitors = getMonitors()
    term.clear(); term.setCursorPos(1, 1)
    print("KIMI Adaptive Command Center")
    print("Monitors detected: " .. tostring(#monitors))
    print("Largest monitor is always the energy dashboard.")
end

function M.render(envelope, meta)
    monitors = getMonitors()
    lastEnvelope, lastMeta = envelope, meta or {}
    touchTargets = {}
    for index, entry in ipairs(monitors) do renderOne(entry, envelope, lastMeta, index) end
end

local function redraw(name)
    if not lastEnvelope then return end
    for index, entry in ipairs(monitors) do
        if entry.name == name then renderOne(entry, lastEnvelope, lastMeta or {}, index); return end
    end
end

function M.onPeripheralChange()
    monitors = getMonitors()
    touchTargets = {}
end

function M.handleEvent(event, envelope, action)
    if type(event) ~= "table" or event[1] ~= "monitor_touch" then return end
    local name, x, y = event[2], event[3], event[4]
    for _, target in ipairs(touchTargets[name] or {}) do
        if target.enabled and x >= target.x1 and x <= target.x2 and y >= target.y1 and y <= target.y2 then
            local targetName = target.name
            if targetName == "view_overview" then monitorViews[name] = "overview"
            elseif targetName == "view_energy" then monitorViews[name] = "energy"
            elseif targetName == "view_sensors" then monitorViews[name] = "sensors"
            elseif targetName == "view_doors" then monitorViews[name] = "doors"
            elseif targetName == "view_fleet" then monitorViews[name] = "fleet"
            elseif targetName == "door_add_view" then monitorViews[name] = "door_add"
            elseif targetName == "door_remove_view" then monitorViews[name] = "door_remove"
            elseif targetName == "page_prev" and target.data then pageState[target.data.key] = math.max(1, (pageState[target.data.key] or 1) - 1)
            elseif targetName == "page_next" and target.data then pageState[target.data.key] = (pageState[target.data.key] or 1) + 1
            elseif targetName == "sync_fleet" and action then
                setToast(name, "SYNC REQUEST SENT TO EVERY KIMI COMPUTER", colors.lime)
                action("server", "sync_fleet", {})
            elseif targetName == "check_updates" and action then
                setToast(name, "CHECKING GITHUB - MAIN SERVER UPDATES FIRST", colors.yellow)
                action("server", "check_updates", {})
            elseif targetName == "door_register" and action then
                local result = action("doors", "register", target.data or {})
                if type(result) == "table" and result.ok == false then
                    setToast(name, "ADD FAILED: " .. tostring(result.error or "unknown error"), colors.red)
                else
                    setToast(name, "DOOR ADDED", colors.lime)
                    monitorViews[name] = "doors"
                end
            elseif targetName == "door_remove" and action then
                local result = action("doors", "remove", target.data or {})
                if type(result) == "table" and result.ok == false then
                    setToast(name, "REMOVE FAILED: " .. tostring(result.error or "unknown error"), colors.red)
                else
                    setToast(name, "DOOR REMOVED", colors.orange)
                    monitorViews[name] = "doors"
                end
            elseif targetName == "door_toggle" and action then
                local result = action("doors", "toggle", target.data or {})
                if type(result) == "table" and result.ok == false then
                    setToast(name, "DOOR FAILED: " .. tostring(result.error or "unknown error"), colors.red)
                else
                    setToast(name, "DOOR COMMAND SENT", colors.lime)
                end
            end
            redraw(name)
            return true
        end
    end
end

return M
