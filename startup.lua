-- KIMI Base OS startup watchdog
local roleFile = ".kimi_role"

local function readRole()
    if not fs.exists(roleFile) then return "wall" end
    local f = fs.open(roleFile, "r")
    local role = f.readAll()
    f.close()
    return (role:gsub("%s+", ""))
end

while true do
    local role = readRole()
    local target = role == "server" and "server.lua" or "client.lua"

    local ok, err = pcall(function()
        shell.run(target)
    end)

    term.setTextColor(colors.red)
    print("KIMI stopped: " .. tostring(err))
    term.setTextColor(colors.white)
    print("Restarting in 3 seconds...")
    sleep(3)
end
