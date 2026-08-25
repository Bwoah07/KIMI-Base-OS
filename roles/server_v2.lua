-- Fleet-authority wrapper for the normal server role.
-- It keeps the existing server implementation, but guarantees every
-- update.available packet carries the exact installed manifest/ref.
-- It also terminates Pocket remote-door routing at the owning room computer:
-- Pocket -> Main Base (remote_doors) -> room computer (doors) -> local actuator.
local network = require("core.network")
local updates = require("core.update_service")
local base = require("roles.server")

local originalSend = network.send
local wrapped = false

local function copyTable(src)
    local out = {}
    for k, v in pairs(src or {}) do out[k] = v end
    return out
end

local function installFleetAuthority()
    if wrapped then return end
    wrapped = true
    network.send = function(target, cfg, kind, payload)
        if kind == "update.available" and type(payload) == "table" then
            local notice = updates.releaseNotice(payload.reason or "fleet-sync")
            payload.version = notice.version
            payload.manifest = notice.manifest
            payload.issuedBy = notice.issuedBy
        elseif kind == "module.command" and type(payload) == "table" and payload.module == "remote_doors" then
            -- Main Base has already resolved the owning computer from args._source.
            -- The destination must execute its LOCAL doors module, not route the
            -- request through remote_doors a second time.
            local localPayload = copyTable(payload)
            localPayload.module = "doors"
            localPayload.remote = true
            payload = localPayload
        end
        return originalSend(target, cfg, kind, payload)
    end
end

local M = {}
function M.run(cfg)
    installFleetAuthority()
    return base.run(cfg)
end

return M
