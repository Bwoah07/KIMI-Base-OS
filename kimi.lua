-- KIMI Base OS kernel entrypoint
local config = require("core.config")
local watchdog = require("core.watchdog")
local updates = require("core.update_service")

local cfg = config.load()
local role = cfg.role or "client"
local rolePath = "roles." .. role

local ok, roleModule = pcall(require, rolePath)
if not ok then
    error("Unable to load role '" .. tostring(role) .. "': " .. tostring(roleModule))
end

-- Newly installed builds get a probation boot. If the role cannot stay alive
-- for 15 seconds, startup.lua will see update_pending and can roll back.
if updates.hasPendingProbation() then
    local winner = parallel.waitForAny(
        function()
            roleModule.run(cfg)
            error("role exited during update probation")
        end,
        function()
            sleep(15)
        end
    )

    if winner ~= 2 then
        error("updated role failed probation")
    end

    updates.markHealthy()
    term.setTextColor(colors.lime)
    print("[KIMI] update probation passed")
    term.setTextColor(colors.white)
end

parallel.waitForAny(
    function()
        watchdog.run("role:" .. role, function()
            roleModule.run(cfg)
        end)
    end,
    function()
        updates.periodic(cfg.update)
    end
)
