-- Direct Pocket door transport + profile-aware client workload trimming.
-- Pocket door actuation bypasses Main Base entirely: Pocket -> owning room PC.
-- The normal client role still owns state/fleet/update/UI behavior.
local network = require("core.network")
local loader = require("core.module_loader")
local base = require("roles.client_v3")

local M = {}

local function unpackEvent(e)
    local u = table.unpack or unpack
    return u(e)
end

local function copyTable(src)
    local out = {}
    for k,v in pairs(src or {}) do out[k]=v end
    return out
end

local function normalizedProfile(name)
    local n=tostring(name or "terminal")
    if n=="room" or n:match("^adaptive") then return "wall" end
    return n
end

function M.run(cfg)
    local realPullEvent=os.pullEvent
    local realSend=network.send
    local realReadAll=loader.readAll
    local profile=normalizedProfile(cfg and cfg.profile)
    local selfId=os.getComputerID()
    local pending={}
    local byDoor={}
    local RETRY_SECONDS=0.25
    local MAX_ATTEMPTS=10

    local function cancel(tx)
        if tx and tx.timer and type(os.cancelTimer)=="function" then pcall(os.cancelTimer,tx.timer) end
        if tx then tx.timer=nil end
    end

    local function clearTx(tx)
        if not tx then return end
        cancel(tx)
        pending[tx.id]=nil
        if byDoor[tx.doorKey]==tx.id then byDoor[tx.doorKey]=nil end
    end

    local function directResult(tx,ok,result,err)
        return {
            module="remote_doors",
            action=tx.action,
            requestId=tx.id,
            ok=ok==true,
            confirmed=ok==true,
            error=err,
            sourceId=tx.target,
            result=result,
            attempts=tx.attempts,
            direct=true,
        }
    end

    local function sendAttempt(tx)
        cancel(tx)
        tx.attempts=tx.attempts+1
        realSend(tx.target,cfg,"door.command.direct",{
            module="doors",
            action=tx.action,
            args=tx.args,
            requestId=tx.id,
            issuedBy=selfId,
            attempt=tx.attempts,
        })
        tx.timer=os.startTimer(RETRY_SECONDS)
    end

    local function startDirect(payload)
        local args=type(payload.args)=="table" and copyTable(payload.args) or {}
        local action=tostring(payload.action or "")
        if action~="open" and action~="close" then return false,"direct door requires open/close" end
        local target=tonumber(args.source or args._source)
        if not target or target==selfId then return false,"invalid room owner" end
        local id=tostring(args.requestId or "")
        if id=="" then id=string.format("direct:%d:%d",selfId,os.epoch("utc")) end
        args.source=tostring(target);args._source=tostring(target);args.requestId=id
        local key=table.concat({tostring(target),tostring(args.target or ""),tostring(args.side or "")},"|")
        local old=byDoor[key] and pending[byDoor[key]] or nil
        if old then clearTx(old) end
        local tx={id=id,target=target,action=action,args=args,doorKey=key,attempts=0}
        pending[id]=tx;byDoor[key]=id
        sendAttempt(tx)
        return true
    end

    loader.readAll=function(modules,previous)
        if profile=="pocket" then return previous or {} end
        if profile=="wall" then
            local lean={}
            for _,id in ipairs({"doors","environment","attachments","system"}) do
                if modules and modules[id] then lean[id]=modules[id] end
            end
            return realReadAll(lean,previous)
        end
        return realReadAll(modules,previous)
    end

    network.send=function(id,sendCfg,kind,payload)
        if profile=="pocket" and kind=="fleet.hello" then return true end
        if profile=="pocket" and kind=="telemetry.state" then return true end
        if profile=="pocket" and kind=="command" and type(payload)=="table" and
           (payload.module=="remote_doors" or payload.module=="direct_doors") then
            return startDirect(payload)
        end
        return realSend(id,sendCfg,kind,payload)
    end

    local function handleDirectCommand(sender,msg)
        local payload=type(msg.payload)=="table" and msg.payload or {}
        if msg.kind~="door.command.direct" or tostring(payload.module or "")~="doors" then return false end
        local args=type(payload.args)=="table" and payload.args or {}
        local action=tostring(payload.action or "")
        local requestId=tostring(payload.requestId or args.requestId or "")
        if action~="open" and action~="close" then return true end
        if tostring(args.source or args._source or "")~=tostring(selfId) then
            realSend(sender,cfg,"door.command.direct.result",{requestId=requestId,action=action,ok=false,error="wrong room owner",sourceId=selfId})
            return true
        end
        local doors=require("modules.doors")
        local state=type(doors.read)=="function" and doors.read() or nil
        local ok,result=pcall(doors.handleCommand,action,args,state)
        realSend(sender,cfg,"door.command.direct.result",{
            requestId=requestId,action=action,ok=ok,result=ok and result or nil,
            error=ok and nil or tostring(result),sourceId=selfId,
            target=args.target,side=args.side,direct=true,
        })
        return true
    end

    local function handleDirectResult(sender,msg)
        if msg.kind~="door.command.direct.result" then return nil end
        local payload=type(msg.payload)=="table" and msg.payload or {}
        local id=tostring(payload.requestId or "")
        local tx=id~="" and pending[id] or nil
        if not tx or tonumber(sender)~=tonumber(tx.target) then return false end
        local event=directResult(tx,payload.ok==true,payload.result,payload.error)
        clearTx(tx)
        return event
    end

    local function handleRetry(timerId)
        for _,tx in pairs(pending) do
            if tx.timer==timerId then
                tx.timer=nil
                if tx.attempts>=MAX_ATTEMPTS then
                    local event=directResult(tx,false,nil,"room computer did not answer direct door command")
                    clearTx(tx)
                    return event
                end
                sendAttempt(tx)
                return false
            end
        end
        return nil
    end

    os.pullEvent=function(filter)
        while true do
            local e={realPullEvent(filter)}
            if e[1]=="timer" then
                local result=handleRetry(e[2])
                if type(result)=="table" then return "kimi_command_result",result end
                if result==false then
                else return unpackEvent(e) end
            elseif e[1]=="rednet_message" and e[4]==cfg.network.protocol and type(e[3])=="table" then
                local sender,msg=e[2],e[3]
                if handleDirectCommand(sender,msg) then
                else
                    local result=handleDirectResult(sender,msg)
                    if type(result)=="table" then return "kimi_command_result",result end
                    if result==false then
                    else return unpackEvent(e) end
                end
            else
                return unpackEvent(e)
            end
        end
    end

    local ok,result=xpcall(function()return base.run(cfg)end,function(err)return err end)
    os.pullEvent=realPullEvent
    network.send=realSend
    loader.readAll=realReadAll
    for _,tx in pairs(pending) do cancel(tx) end
    if not ok then error(result,0) end
    return result
end

return M
