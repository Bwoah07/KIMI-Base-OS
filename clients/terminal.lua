local M = {}
local lastDraw = nil

local function gameTime()
    local t = os.time("ingame") % 24
    local h = math.floor(t)
    local m = math.floor((t - h) * 60)
    return string.format("%02d:%02d", h, m)
end

function M.init()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
end

function M.render(envelope, meta)
    local env = envelope and envelope.state and envelope.state.environment or nil
    local sys = envelope and envelope.state and envelope.state.system or nil
    local signature = table.concat({ tostring(meta.connected), gameTime(), tostring(env and env.weather), tostring(env and env.biome), tostring(env and env.moon), tostring(sys and sys.computerId) }, "|")
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
end

return M
