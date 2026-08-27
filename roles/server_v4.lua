-- Alpha73 release watcher: Main Base becomes hands-off update authority.
-- The transactional updater still reboots for a release/probation, but the user
-- no longer has to manually reboot Main Base after every merge.
local base=require("roles.server_v3")
local M={}
local function copy(t)local o={};for k,v in pairs(t or{})do o[k]=v end;return o end
function M.run(cfg)
 local c=copy(cfg);c.update=copy(cfg and cfg.update)
 if c.update.auto~=false then c.update.interval=60 end
 return base.run(c)
end
return M
