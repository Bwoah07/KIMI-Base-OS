-- KIMI Base OS bootloader/watchdog
while true do
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    local ok, err = pcall(function()
        shell.run("kimi")
    end)
    if ok then return end
    term.setTextColor(colors.red)
    print("[KIMI] kernel stopped: " .. tostring(err))
    term.setTextColor(colors.white)
    print("[KIMI] rebooting kernel in 3s...")
    sleep(3)
end
