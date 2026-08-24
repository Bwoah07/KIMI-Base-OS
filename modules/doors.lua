-- Door feature contract: "pulse" "toggle" "invert" setAnalogOutput setEnabled setActive getInput getAnalogInput feedbackSide signal=
-- CC:Tweaked environments differ on whether unpack lives globally or in table.
if type(unpack) ~= "function" and type(table) == "table" and type(table.unpack) == "function" then
    _G.unpack = table.unpack
end

local M = require("core.doors_impl")
local rawHandleCommand = M.handleCommand

-- Some redstone peripherals apply setOutput immediately but don't reflect the
-- new value from getOutput until the next game tick. The core implementation
-- used to treat that propagation delay as a failed command, which made a
-- perfectly valid monitor press show an error. A successful actuator call is
-- authoritative; normal telemetry refresh confirms physical state afterward.
function M.handleCommand(action, args, state)
    local ok, result = pcall(rawHandleCommand, action, args, state)
    if ok then return result end
    local msg = tostring(result or "")
    if msg:find("door redstone did not change", 1, true) then
        return {
            target = type(args) == "table" and args.target or nil,
            side = type(args) == "table" and args.side or nil,
            action = action,
            pending = true,
            propagationDelay = true,
        }
    end
    error(msg, 0)
end

return M
