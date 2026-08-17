-- KIMI Base OS kernel entrypoint
local config = require("core.config")
local watchdog = require("core.watchdog")

local cfg = config.load()
local role = cfg.role or "client"
local rolePath = "roles." .. role

local ok, roleModule = pcall(require, rolePath)
if not ok then
    error("Unable to load role '" .. tostring(role) .. "': " .. tostring(roleModule))
end

watchdog.run("role:" .. role, function()
    roleModule.run(cfg)
end)
