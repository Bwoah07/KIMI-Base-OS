-- KIMI Base OS kernel entrypoint
local config = require("core.config")
local watchdog = require("core.watchdog")
local updates = require("core.update_service")

local cfg = config.load()
local role = cfg.role or "client"
local rolePath
if role == "server" then rolePath = "roles.server_v6"
elseif role == "client" then rolePath = "roles.client_v8"
elseif role == "node" then rolePath = "roles.node_v5"
else rolePath = "roles." .. role end

local ok, roleModule = pcall(require, rolePath)
if not ok then error("Unable to load role '" .. tostring(role) .. "': " .. tostring(roleModule)) end

if updates.hasPendingProbation() then
    local winner = parallel.waitForAny(
        function() roleModule.run(cfg); error("role exited during update probation") end,
        function() sleep(15) end
    )
    if winner ~= 2 then error("updated role failed probation") end
    updates.markHealthy()
    updates.requestLiveReload("probation-complete")
    term.setTextColor(colors.lime)
    print("[KIMI] update probation passed; live reloading cleanly")
    term.setTextColor(colors.white)
    return
end

watchdog.run("role:" .. role, function() roleModule.run(cfg) end)
