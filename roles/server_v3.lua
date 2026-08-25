-- Non-blocking remote-door transport in front of the normal Main Base server.
--
-- Alpha65 waited synchronously inside modules.remote_doors. That made the whole
-- server stop consuming normal KIMI events while a door ACK was pending. If a
-- room client happened to be busy polling/rendering, a clean single click could
-- miss every short ACK window; spamming merely kept commands in flight longer.
--
-- This wrapper intercepts only remote_doors OPEN/CLOSE commands. The normal
-- server loop continues running while a transaction is pending. Commands are
-- retried idempotently and matched to the room result with a unique requestId.
local network = require("core.network")
local base = require("roles.server_v2")

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
    local pending = {}
    local byDoor = {}
    local counter = 0
    local selfId = os.getComputerID()
    local RETRY_SECONDS = 0.8
    local MAX_ATTEMPTS = 6

    local function cancelTimer(tx)
        if tx and tx.timer and type(os.cancelTimer) == "function" then
            pcall(os.cancelTimer, tx.timer)
        end
        if tx then tx.timer = nil end
    end

    local function clearTx(tx)
        if not tx then return end
        cancelTimer(tx)
        pending[tx.id] = nil
        if byDoor[tx.doorKey] == tx.id then byDoor[tx.doorKey] = nil end
    end

    local function replyRequester(tx, ok, result, err)
        if not tx then return end
        network.send(tx.requester, cfg, "command.result", {
            ok = ok == true,
            result = result,
            error = err,
            module = "remote_doors",
            action = tx.action,
            requestId = tx.id,
            sourceId = tx.target,
            attempts = tx.attempts,
            confirmed = ok == true,
        })
    end

    local function sendAttempt(tx)
        if not tx then return false end
        cancelTimer(tx)
        tx.attempts = tx.attempts + 1
        local sent = network.send(tx.target, cfg, "module.command", {
            module = "doors",
            action = tx.action,
            args = tx.args,
            issuedBy = selfId,
            remote = true,
            requestId = tx.id,
            attempt = tx.attempts,
        })
        tx.lastSendOk = sent == true
        tx.timer = os.startTimer(RETRY_SECONDS)
        return sent == true
    end

    local function startRemoteDoor(sender, payload)
        local args = type(payload.args) == "table" and payload.args or {}
        local action = tostring(payload.action or "")
        if action ~= "open" and action ~= "close" then return false end

        -- Pocket sends the owning room computer as `source`. `_source` is kept
        -- reserved for the destination ownership check.
        local source = tostring(args.source or args._source or "")
        local target = tonumber(source)
        if not target or target == selfId then return false end

        local routedArgs = copyTable(args)
        routedArgs.source = source
        routedArgs._source = source

        local doorKey = table.concat({source, tostring(args.target or ""), tostring(args.side or "")}, "|")

        -- Latest intent wins. This also means frantic spam cannot leave six
        -- alternating OPEN/CLOSE transactions fighting over one door.
        local oldId = byDoor[doorKey]
        local old = oldId and pending[oldId] or nil
        if old then
            replyRequester(old, false, nil, "superseded by newer door command")
            clearTx(old)
        end

        counter = counter + 1
        local id = string.format("door:%d:%d:%d:%d", selfId, tonumber(sender) or 0, os.epoch("utc"), counter)
        local tx = {
            id = id,
            requester = tonumber(sender) or sender,
            target = target,
            action = action,
            args = routedArgs,
            doorKey = doorKey,
            attempts = 0,
        }
        pending[id] = tx
        byDoor[doorKey] = id
        sendAttempt(tx)
        return true
    end

    local function handleAck(sender, msg)
        if type(msg) ~= "table" or msg.kind ~= "module.command.result" then return false end
        local payload = type(msg.payload) == "table" and msg.payload or {}
        local id = tostring(payload.requestId or "")
        if id == "" then return false end
        local tx = pending[id]
        if not tx or tonumber(sender) ~= tonumber(tx.target) then return false end

        if payload.ok == true then
            replyRequester(tx, true, payload.result, nil)
        else
            replyRequester(tx, false, payload.result, payload.error or tostring(payload.result or "door command failed"))
        end
        clearTx(tx)
        return true
    end

    local function handleRetryTimer(timerId)
        for _, tx in pairs(pending) do
            if tx.timer == timerId then
                tx.timer = nil
                if tx.attempts >= MAX_ATTEMPTS then
                    replyRequester(tx, false, nil,
                        "room computer did not confirm door command after " .. tostring(tx.attempts) .. " attempts")
                    clearTx(tx)
                else
                    sendAttempt(tx)
                end
                return true
            end
        end
        return false
    end

    local function interceptedPullEvent(filter)
        while true do
            local e = {realPullEvent(filter)}

            if e[1] == "timer" and handleRetryTimer(e[2]) then
                -- Private retry timer: consume it and keep the real server loop
                -- moving instead of exposing transport internals to roles.server.
            elseif e[1] == "rednet_message" and e[4] == cfg.network.protocol and type(e[3]) == "table" then
                local sender, msg = e[2], e[3]
                local payload = type(msg.payload) == "table" and msg.payload or {}

                if handleAck(sender, msg) then
                    -- The base server never handled module.command.result anyway;
                    -- consume the correlated ACK here.
                elseif msg.kind == "command" and payload.module == "remote_doors" and
                       (payload.action == "open" or payload.action == "close") and
                       startRemoteDoor(sender, payload) then
                    -- Consume only the door command we successfully turned into
                    -- an async transaction. All other KIMI traffic passes through.
                else
                    return unpackEvent(e)
                end
            else
                return unpackEvent(e)
            end
        end
    end

    os.pullEvent = interceptedPullEvent
    local ok, result = xpcall(function() return base.run(cfg) end, function(err) return err end)
    os.pullEvent = realPullEvent

    if not ok then error(result, 0) end
    return result
end

return M
