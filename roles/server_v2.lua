-- Fleet-authority wrapper for the normal server role.
-- It keeps the existing server implementation, but guarantees every
-- update.available packet carries the exact installed manifest/ref.
local network = require("core.network")
local updates = require("core.update_service")
local base = require("roles.server")

local originalSend = network.send
local wrapped = false

local function installFleetAuthority()
    if wrapped then return end
    wrapped = true
    network.send = function(target, cfg, kind, payload)
        if kind == "update.available" and type(payload) == "table" then
            local notice = updates.releaseNotice(payload.reason or "fleet-sync")
            payload.version = notice.version
            payload.manifest = notice.manifest
            payload.issuedBy = notice.issuedBy
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