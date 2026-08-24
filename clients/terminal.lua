local M = {}
local lastDraw = nil

local function gameTime()
    local t = os.time("ingame") % 24
    local h = math.floor(t)
    local m = math.floor((t - h) * 60)
    return string.format("%02d:%02d", h, m)
end

local function fmtNumber(value)
    local n=tonumber(value)
    if not n then return "?" end
    local a=math.abs(n)
    if a>=1e12 then return string.format("%.2fT",n/1e12) end
    if a>=1e9 then return string.format("%.2fG",n/1e9) end
    if a>=1e6 then return string.format("%.2fM",n/1e6) end
    if a>=1e3 then return string.format("%.2fK",n/1e3) end
    return tostring(math.floor(n+0.5))
end

local function fmtFE(value, rate)
    local text=fmtNumber(value)
    return text=="?" and text or (text.." FE"..(rate and "/t" or ""))
end

function M.init()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
end

function M.render(envelope, meta)
    local env = envelope and envelope.state and envelope.state.environment or nil
    local sys = envelope and envelope.state and envelope.state.system or nil
    local power = envelope and envelope.state and envelope.state.power or nil
    local attachments = envelope and envelope.state and envelope.state.attachments or nil
    local doors = envelope and envelope.state and envelope.state.doors or nil
    local signature = table.concat({ tostring(meta.connected), tostring(meta.localVersion), gameTime(), tostring(env and env.weather), tostring(env and env.biome), tostring(env and env.moon), tostring(sys and sys.computerId), tostring(power and power.sourceType), tostring(power and power.networkName), tostring(power and power.stored), tostring(power and power.input), tostring(power and power.output), tostring(power and power.fluxCount), tostring(power and power.matrixCount), tostring(attachments and attachments.count), tostring(attachments and attachments.sensorCount), tostring(doors and doors.doorCount) }, "|")
    if signature == lastDraw then return end
    lastDraw = signature

    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.red)
    print("KIMI BASE OS")
    term.setTextColor(colors.white)
    print("Client " .. os.getComputerID() .. "  " .. gameTime())
    print("")
    if not meta.connected or not envelope then
        term.setTextColor(colors.yellow)
        print("Searching for KIMI server...")
        return
    end
    term.setTextColor(colors.lime)
    print("SERVER ONLINE")
    term.setTextColor(colors.white)
    local osState="?"
    if meta.localVersion then osState=tostring(meta.localVersion)..((envelope.version and meta.localVersion~=envelope.version) and (" -> "..tostring(envelope.version)) or " CURRENT") end
    print("OS:      " .. osState)
    print("Weather: " .. tostring(env and env.weather or "UNKNOWN"))
    print("Day/time:" .. tostring(sys and sys.ingameDay or "?") .. " / " .. gameTime())
    print("Biome:   " .. tostring(env and env.biome or "UNKNOWN"))
    print("Moon:    " .. tostring(env and env.moon or "UNKNOWN"))
    print("Attach:  " .. tostring(attachments and attachments.count or 0) .. " total / " .. tostring(attachments and attachments.sensorCount or 0) .. " sensors")
    print("Doors:   " .. tostring(doors and doors.doorCount or 0) .. " configured / " .. tostring(doors and doors.candidateCount or 0) .. " candidates")
    local powerStatus=tostring(power and (power._status or power.status) or ""):lower()
    if power and power.sourceType and powerStatus~="offline" and powerStatus~="error" and powerStatus~="disconnected" then
        print("")
        term.setTextColor(power.sourceType=="flux_network" and colors.red or colors.lime)
        print(power.sourceType=="flux_network" and "FLUX NETWORKS" or "POWER NETWORK")
        term.setTextColor(colors.white)
        print("Network: " .. tostring(power.networkName or "---"))
        print("Stored:  " .. fmtFE(power.stored,false) .. " / " .. fmtFE(power.capacity,false))
        print("Flow:    +" .. fmtFE(power.input,true) .. "  -" .. fmtFE(power.output,true))
        print("Sources: Flux "..tostring(power.fluxCount or 0).." / Matrix "..tostring(power.matrixCount or 0))
        if power.sourceType=="flux_network" then
            print("Devices: P:"..tostring(power.plugs or "?").." PT:"..tostring(power.points or "?").." S:"..tostring(power.storages or "?").." C:"..tostring(power.controllers or "?"))
        end
        for index,value in ipairs(power.fluxNetworks or {}) do
            print("Flux "..tostring(index)..": "..tostring(value.networkName or value.peripheral).."  "..fmtFE(value.stored,false))
        end
    end
end

return M

