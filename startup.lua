-- KIMI Base OS bootloader / recovery watchdog
local ROOT = ".kimi"
local PENDING = ROOT .. "/update_pending"

local function readPending()
    if not fs.exists(PENDING) then return nil end
    local f = fs.open(PENDING, "r")
    if not f then return nil end
    local raw = f.readAll(); f.close()
    return textutils.unserialize(raw)
end

local function writePending(data)
    local f = assert(fs.open(PENDING, "w"))
    f.write(textutils.serialize(data))
    f.close()
end

local function tryAutoUpdate()
    if not fs.exists("updater.lua") then return end
    local ok, result = pcall(function()
        return shell.run("updater", "auto")
    end)
    if not ok or result == false then
        term.setTextColor(colors.yellow)
        print("[KIMI] update check failed; booting installed version")
        term.setTextColor(colors.white)
    end
end

if not fs.exists(ROOT) then fs.makeDir(ROOT) end
tryAutoUpdate()

while true do
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)

    local ok, ran = pcall(function()
        return shell.run("kimi")
    end)
    local success = ok and ran ~= false

    -- KIMI is designed to be long-running. Any exit is treated as a fault.
    local pending = readPending()
    if pending then
        pending.crashes = (tonumber(pending.crashes) or 0) + 1
        writePending(pending)

        if pending.crashes >= 3 then
            term.setTextColor(colors.red)
            print("[KIMI] new update failed repeatedly; restoring last known-good build...")
            term.setTextColor(colors.white)
            local rbOk, rbResult = pcall(function()
                return shell.run("updater", "rollback")
            end)
            if rbOk and rbResult ~= false then
                sleep(1)
                os.reboot()
            else
                print("[KIMI] automatic rollback failed; leaving recovery files intact")
            end
        end
    end

    term.setTextColor(colors.red)
    print("[KIMI] kernel stopped" .. (success and "" or " unexpectedly"))
    term.setTextColor(colors.white)
    print("[KIMI] restarting kernel in 3s...")
    sleep(3)
end
