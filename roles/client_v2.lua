-- Client wrapper that preserves Main Base's requestId through the room command
-- execution result. The underlying roles.client remains the actuator/event-loop
-- implementation; this wrapper only adds transaction correlation metadata.
local network = require("core.network")
local base = require("roles.client")

local M = {}

local function copyTable(src)
    local out = {}
    for k, v in pairs(src or {}) do out[k] = v end
    return out
end

local function unpackEvent(e)
    local u = table.unpack or unpack
    return u(e)
end

function M.run(cfg)
    local realPullEvent = os.pullEvent
    local realSend = network.send
    local activeRequestId = nil

    os.pullEvent = function(filter)
        local e = {realPullEvent(filter)}
        if e[1] == "rednet_message" and e[4] == cfg.network.protocol and type(e[3]) == "table" then
            local msg = e[3]
            local payload = type(msg.payload) == "table" and msg.payload or {}
            if msg.kind == "module.command" and payload.requestId ~= nil then
                activeRequestId = tostring(payload.requestId)
            end
        end
        return unpackEvent(e)
    end

    network.send = function(target, sendCfg, kind, payload)
        if kind == "module.command.result" and activeRequestId then
            local routed = copyTable(payload)
            routed.requestId = activeRequestId
            payload = routed
            activeRequestId = nil
        end
        return realSend(target, sendCfg, kind, payload)
    end

    local ok, result = xpcall(function() return base.run(cfg) end, function(err) return err end)
    network.send = realSend
    os.pullEvent = realPullEvent

    if not ok then error(result, 0) end
    return result
end

return M
