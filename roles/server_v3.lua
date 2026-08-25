-- Non-blocking remote-door transport in front of the normal Main Base server.
-- Pocket and local Command Center controls share the same retry/ACK machinery.
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
    -- Door controls should feel like a remote, not a web form. If the first
    -- packet misses, retry quickly while remaining completely non-blocking.
    local RETRY_SECONDS = 0.35
    local MAX_ATTEMPTS = 8
    local previousAsyncHook = rawget(_G, "kimiRemoteDoorAsync")

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
        if not tx or tx.requester == nil then return end
        network.send(tx.requester, cfg, "command.result", {
            ok = ok == true,
            result = result,
            error = err,
            module = "remote_doors",
            action = tx.action,
            requestId = tx.id,
            sourceId = tx.target,
            target = tx.args and tx.args.target or nil,
            side = tx.args and tx.args.side or nil,
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
        payload = type(payload) == "table" and payload or {}
        local args = type(payload.args) == "table" and payload.args or {}
        local action = tostring(payload.action or "")
        if action ~= "open" and action ~= "close" then return false end

        local source = tostring(args.source or args._source or "")
        local target = tonumber(source)
        if not target or target == selfId then return false end

        local routedArgs = copyTable(args)
        routedArgs.source = source
        routedArgs._source = source

        local doorKey = table.concat({source, tostring(args.target or ""), tostring(args.side or "")}, "|")

        -- Latest intent wins. Rapid OPEN/CLOSE/OPEN touches intentionally replace
        -- the older transaction instead of queueing contradictory commands.
        local oldId = byDoor[doorKey]
        local old = oldId and pending[oldId] or nil
        if old then
            replyRequester(old, false, nil, "superseded by newer door command")
            clearTx(old)
        end

        counter = counter + 1
        -- Pocket supplies a globally unique client requestId so late results from
        -- superseded taps can never settle a newer UI intent. Local wall controls
        -- may omit it and use the generated fallback below.
        local requestedId = tostring(args.requestId or payload.requestId or "")
        local id
        if requestedId ~= "" and pending[requestedId] == nil then
            id = requestedId
        else
            id = string.format("door:%d:%d:%d:%d", selfId, tonumber(sender) or 0, os.epoch("utc"), counter)
        end
        routedArgs.requestId = id

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
        return true, tx
    end

    -- Local Command Center actions do not arrive as rednet `command` packets,
    -- so expose the same async transaction manager through a tiny module bridge.
    _G.kimiRemoteDoorAsync = function(action, args)
        args = type(args) == "table" and args or {}
        action = tostring(action or "")
        if action ~= "open" and action ~= "close" then error("async door control requires explicit open/close") end
        local source = tostring(args.source or args._source or "")
        if source == "" then error("door owner/source is missing") end

        if source == "server" or source == tostring(selfId) then
            local doors = require("modules.doors")
            local localState = type(doors.read) == "function" and doors.read() or nil
            return doors.handleCommand(action, args, localState)
        end

        local started, tx = startRemoteDoor(nil, {action=action,args=args})
        if not started or not tx then error("invalid remote door owner/source") end
        return {
            queued = true,
            confirmed = false,
            async = true,
            sourceId = tx.target,
            requestId = tx.id,
            attempts = tx.attempts,
        }
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
                -- private retry timer; keep normal server loop free
            elseif e[1] == "rednet_message" and e[4] == cfg.network.protocol and type(e[3]) == "table" then
                local sender, msg = e[2], e[3]
                local payload = type(msg.payload) == "table" and msg.payload or {}

                if handleAck(sender, msg) then
                    -- correlated room execution result consumed here
                elseif msg.kind == "command" and payload.module == "remote_doors" and
                       (payload.action == "open" or payload.action == "close") and
                       startRemoteDoor(sender, payload) then
                    -- Pocket command converted into async transaction
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
    _G.kimiRemoteDoorAsync = previousAsyncHook

    if not ok then error(result, 0) end
    return result
end

return M
