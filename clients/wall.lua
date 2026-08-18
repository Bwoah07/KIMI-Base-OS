local M = {}

local monitors = {}

local function getMonitors()
    local out = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "monitor") then
            out[#out + 1] = { name = name, mon = peripheral.wrap(name) }
        end
    end
    table.sort(out, function(a,b) return a.name < b.name end)
    return out
end

local function prep(mon)
    pcall(mon.setTextScale, 0.5)
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.white)
    mon.clear()
    mon.setCursorPos(1,1)
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

local function line(mon, y, text, color)
    local w, h = mon.getSize()
    if y > h then return end
    mon.setCursorPos(2,y)
    mon.setTextColor(color or colors.white)
    mon.write(tostring(text or ""):sub(1, math.max(0, w - 2)))
end

local function count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

local function gameTime()
    local t = os.time("ingame") % 24
    local h = math.floor(t)
    local m = math.floor((t - h) * 60)
    return string.format("%02d:%02d", h, m)
end

local function panelOverview(mon, envelope, meta)
    prep(mon); header(mon, "KIMI BASE")
    line(mon,3,meta.connected and "SERVER ONLINE" or "SEARCHING FOR SERVER", meta.connected and colors.lime or colors.yellow)
    line(mon,5,"Time     " .. gameTime())
    line(mon,7,"Server   " .. tostring(meta.serverId or "---"))
    line(mon,9,"Version  " .. tostring(envelope and envelope.version or "?"))
    local state = envelope and envelope.state or {}
    line(mon,11,"Sources  " .. tostring(count(state.sources)))
end

local function panelEnvironment(mon, envelope)
    prep(mon); header(mon, "ENVIRONMENT")
    local env = envelope and envelope.state and envelope.state.environment or nil
    if not env then
        line(mon,3,"No environment sensor", colors.yellow)
        line(mon,5,"Waiting for any KIMI", colors.lightGray)
        line(mon,7,"client/node with sensor", colors.lightGray)
        return
    end
    line(mon,3,"Weather  " .. tostring(env.weather or "UNKNOWN"), colors.white)
    line(mon,5,"Biome    " .. tostring(env.biome or "UNKNOWN"), colors.white)
    line(mon,7,"Moon     " .. tostring(env.moon or "UNKNOWN"), colors.white)
    line(mon,9,"Status   " .. tostring(env._status or "?"), env._status == "online" and colors.lime or colors.yellow)
    line(mon,11,"Source   " .. tostring(env._source or "server"), colors.lightGray)
end

local function panelPower(mon, envelope)
    prep(mon); header(mon, "POWER")
    local p = envelope and envelope.state and envelope.state.power or nil
    if not p then line(mon,3,"No power telemetry", colors.yellow); return end
    line(mon,3,"Status   " .. tostring(p.status or p._status or "UNKNOWN"))
    line(mon,5,"Stored   " .. tostring(p.stored or "?"))
    line(mon,7,"Capacity " .. tostring(p.capacity or "?"))
    line(mon,9,"Input    " .. tostring(p.input or "?"))
    line(mon,11,"Output   " .. tostring(p.output or "?"))
end

local function panelStorage(mon, envelope)
    prep(mon); header(mon, "AE2 / STORAGE")
    local s = envelope and envelope.state and (envelope.state.ae2 or envelope.state.storage) or nil
    if not s then line(mon,3,"No storage telemetry", colors.yellow); return end
    line(mon,3,"Status   " .. tostring(s._status or (s.online and "online" or "unknown")), s.online == false and colors.red or colors.lime)
    line(mon,5,"Items    " .. tostring(s.items or s.itemCount or "?"))
    line(mon,7,"Crafting " .. tostring(s.craftingJobs or "?"))
    line(mon,9,"Source   " .. tostring(s._source or "server"), colors.lightGray)
end

local function panelFleet(mon, envelope)
    prep(mon); header(mon, "KIMI FLEET")
    local fleet = envelope and envelope.state and envelope.state.fleet or {}
    local ids = {}
    for id in pairs(fleet) do ids[#ids+1] = id end
    table.sort(ids, function(a,b) return tonumber(a) < tonumber(b) end)
    if #ids == 0 then line(mon,3,"No other machines seen", colors.yellow); return end
    local y = 3
    for _, id in ipairs(ids) do
        local m = fleet[id]
        local online = m.online ~= false
        line(mon,y,(online and "ON " or "OFF ") .. tostring(id) .. " " .. tostring(m.role or "?") .. " " .. tostring(m.version or "?"), online and colors.lime or colors.red)
        y = y + 2
    end
end

local function panelSources(mon, envelope)
    prep(mon); header(mon, "TELEMETRY")
    local sources = envelope and envelope.state and envelope.state.sources or {}
    local ids = {}
    for id in pairs(sources) do ids[#ids+1] = id end
    table.sort(ids)
    if #ids == 0 then line(mon,3,"No remote sources", colors.yellow); return end
    local y = 3
    for _, id in ipairs(ids) do
        local s = sources[id]
        line(mon,y,tostring(id) .. " " .. tostring(s.role or "?") .. " " .. tostring(count(s.state)) .. " modules", s.online == false and colors.red or colors.lime)
        y = y + 2
    end
end

local function panelSystem(mon, envelope, meta)
    prep(mon); header(mon, "SYSTEM")
    line(mon,3,"Client ID " .. tostring(os.getComputerID()))
    line(mon,5,"Server    " .. tostring(meta.serverId or "---"))
    line(mon,7,"Link      " .. (meta.connected and "ONLINE" or "OFFLINE"), meta.connected and colors.lime or colors.red)
    line(mon,9,"Version   " .. tostring(envelope and envelope.version or "?"))
    line(mon,11,"Monitors  " .. tostring(#monitors))
end

local panels = {
    panelOverview,
    panelEnvironment,
    panelPower,
    panelStorage,
    panelFleet,
    panelSources,
    panelSystem
}

function M.init()
    monitors = getMonitors()
    term.clear(); term.setCursorPos(1,1)
    print("KIMI Wall Client")
    print("Monitors detected: " .. tostring(#monitors))
    if #monitors == 0 then print("Attach any number of monitors; KIMI will auto-layout them.") end
end

function M.render(envelope, meta)
    monitors = getMonitors()
    meta = meta or {}
    for i, entry in ipairs(monitors) do
        local fn = panels[((i - 1) % #panels) + 1]
        fn(entry.mon, envelope, meta)
    end
end

function M.onPeripheralChange()
    monitors = getMonitors()
end

function M.handleEvent() end

return M
