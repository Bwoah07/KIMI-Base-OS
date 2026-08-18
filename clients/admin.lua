local M = {}

local monitors = {}

local function getMonitors()
    local out = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "monitor") then
            out[#out + 1] = { name = name, mon = peripheral.wrap(name) }
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

local function prep(mon)
    pcall(mon.setTextScale, 0.5)
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.white)
    mon.clear()
    mon.setCursorPos(1, 1)
end

local function header(mon, title)
    local w = select(1, mon.getSize())
    mon.setBackgroundColor(colors.red)
    mon.setTextColor(colors.white)
    mon.setCursorPos(1,1)
    mon.write(string.rep(" ", w))
    local x = math.max(1, math.floor((w - #title) / 2) + 1)
    mon.setCursorPos(x,1)
    mon.write(title)
    mon.setBackgroundColor(colors.black)
end

local function writeLine(mon, y, text, color)
    local w, h = mon.getSize()
    if y > h then return end
    mon.setCursorPos(2, y)
    mon.setTextColor(color or colors.white)
    mon.write(tostring(text):sub(1, math.max(0, w - 2)))
end

local function countOnline(machines)
    local total, online = 0, 0
    for _, m in pairs(machines or {}) do
        total = total + 1
        if m.online ~= false then online = online + 1 end
    end
    return online, total
end

local function age(ms)
    if not ms then return "never" end
    local d = math.max(0, math.floor((os.epoch("utc") - ms) / 1000))
    if d < 60 then return d .. "s ago" end
    if d < 3600 then return math.floor(d / 60) .. "m ago" end
    return math.floor(d / 3600) .. "h ago"
end

local function panel(mon, index, envelope, meta)
    prep(mon)
    local machines = meta.machines or {}
    local update = meta.update or {}
    local online, total = countOnline(machines)
    local mode = ((index - 1) % 5) + 1

    if mode == 1 then
        header(mon, "KIMI SERVER")
        writeLine(mon,3,"Server ID  " .. tostring(meta.serverId), colors.white)
        writeLine(mon,5,"Version    " .. tostring(envelope and envelope.version or "?"), colors.lime)
        writeLine(mon,7,"Fleet      " .. online .. "/" .. total .. " online", colors.white)
        writeLine(mon,9,"Sources    " .. tostring((function() local n=0 for _ in pairs(meta.sources or {}) do n=n+1 end return n end)()), colors.white)
        writeLine(mon,11,"Update auth THIS SERVER", colors.lightGray)
    elseif mode == 2 then
        header(mon, "FLEET")
        local y = 3
        local ids = {}
        for id in pairs(machines) do ids[#ids+1] = id end
        table.sort(ids, function(a,b) return tonumber(a) < tonumber(b) end)
        for _, id in ipairs(ids) do
            local m = machines[id]
            local status = m.online ~= false and "ON" or "OFF"
            writeLine(mon,y,status .. " " .. tostring(id) .. " " .. tostring(m.role or "?") .. " " .. tostring(m.version or "?"), m.online ~= false and colors.lime or colors.red)
            y = y + 2
        end
        if #ids == 0 then writeLine(mon,3,"No clients/nodes seen", colors.yellow) end
    elseif mode == 3 then
        header(mon, "UPDATES")
        writeLine(mon,3,"Local   " .. tostring(envelope and envelope.version or "?"), colors.white)
        writeLine(mon,5,"Remote  " .. tostring(update.remoteVersion or "?"), colors.white)
        writeLine(mon,7,"Result  " .. tostring(update.lastResult or "?"), colors.white)
        writeLine(mon,9,"Checked " .. age(update.lastCheck), colors.lightGray)
        writeLine(mon,11,"Target  " .. tostring(update.targetVersion or "none"), colors.white)
    elseif mode == 4 then
        header(mon, "NETWORK")
        writeLine(mon,3,"Protocol kimi_base_os_v1", colors.white)
        writeLine(mon,5,"Server   " .. tostring(meta.serverId), colors.white)
        writeLine(mon,7,"Clients  " .. tostring(total), colors.white)
        writeLine(mon,9,"Online   " .. tostring(online), online == total and colors.lime or colors.yellow)
        writeLine(mon,11,"Telemetry sources " .. tostring((function() local n=0 for _ in pairs(meta.sources or {}) do n=n+1 end return n end)()), colors.white)
    else
        header(mon, "HEALTH")
        writeLine(mon,3,"KIMI OS RUNNING", colors.lime)
        writeLine(mon,5,"Update authority OK", colors.lime)
        writeLine(mon,7,"Fleet online " .. online .. "/" .. total, colors.white)
        writeLine(mon,9,"Last check " .. age(update.lastCheck), colors.white)
        writeLine(mon,11,"Computer " .. tostring(os.getComputerID()), colors.lightGray)
    end
end

function M.init()
    monitors = getMonitors()
    term.clear(); term.setCursorPos(1,1)
    print("KIMI Command Center Admin UI")
    print("Monitors detected: " .. tostring(#monitors))
end

function M.render(envelope, meta)
    monitors = getMonitors()
    for i, entry in ipairs(monitors) do panel(entry.mon, i, envelope, meta or {}) end
end

function M.onPeripheralChange()
    monitors = getMonitors()
end

function M.handleEvent() end

return M
