local M = {}

function M.run(name, fn)
    local failures = 0
    while true do
        local ok, err = pcall(fn)
        if ok then return end
        failures = failures + 1
        term.setTextColor(colors.red)
        print("[KIMI] " .. tostring(name) .. " crashed: " .. tostring(err))
        term.setTextColor(colors.white)
        local delay = math.min(30, 2 + failures * 2)
        print("[KIMI] restarting in " .. delay .. "s")
        sleep(delay)
    end
end

function M.safe(label, fn, fallback)
    local ok, value = pcall(fn)
    if ok then return value, true end
    return fallback, false, tostring(value)
end

return M
