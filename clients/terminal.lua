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
    local signature = table.concat({ tostring(meta.connected), gameTime(), tostring(env and env.weather), tostring(env and env.biome), tostring(env and env.moon), tostring(sys and sys.computerId), tostring(power and power.sourceType), tostring(power and power.networkName), tostring(power and power.stored), tostring(power and power.input), tostring(power and power.output) }, "|")
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
    print("Weather: " .. tostring(env and env.weather or "UNKNOWN"))
    print("Biome:   " .. tostring(env and env.biome or "UNKNOWN"))
    print("Moon:    " .. tostring(env and env.moon or "UNKNOWN"))
    if power and (power.status=="ONLINE" or power._status=="online") then
        print("")
        term.setTextColor(power.sourceType=="flux_network" and colors.red or colors.lime)
        print(power.sourceType=="flux_network" and "FLUX NETWORKS" or "POWER NETWORK")
        term.setTextColor(colors.white)
        print("Network: " .. tostring(power.networkName or "---"))
        print("Stored:  " .. fmtFE(power.stored,false) .. " / " .. fmtFE(power.capacity,false))
        print("Flow:    +" .. fmtFE(power.input,true) .. "  -" .. fmtFE(power.output,true))
        if power.sourceType=="flux_network" then
            print("Devices: P:"..tostring(power.plugs or "?").." PT:"..tostring(power.points or "?").." S:"..tostring(power.storages or "?").." C:"..tostring(power.controllers or "?"))
        end
    end
end

return M

