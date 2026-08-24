local M = {}
local network = require("core.network")
local loader = require("core.module_loader")
local updates = require("core.update_service")

local function normalizedProfile(name)
    local n = tostring(name or "terminal")
    if n == "wall" or n == "room" or n:match("^adaptive") then return "wall" end
    return n
end

local function loadProfile(name)
    local resolved = normalizedProfile(name)
    local ok, profile = pcall(require, "clients." .. resolved)
    if ok and type(profile) == "table" then return profile, resolved end
    return require("clients.terminal"), "terminal"
end

local function discoverModules() return loader.discover("modules") end

function M.run(cfg)
    network.openAll()
    network.advertise(cfg, "client")
    local profile, resolvedProfile = loadProfile(cfg.profile)
    local modules = discoverModules()
    local localState = loader.readAll(modules, {})
    local serverId, state, lastSeen = nil, nil, 0
    local lastModuleScan = os.epoch("utc")
    if profile.init then profile.init(cfg) end

    local function helloPayload()
        return {
            clientId=os.getComputerID(), sourceId=os.getComputerID(), role="client",
            name=cfg.name, profile=resolvedProfile, version=updates.localVersion(),
            generated=os.epoch("utc")
        }
    end

    local function meta(connected)
        return {
            connected=connected, lastSeen=lastSeen, serverId=serverId,
            localState=localState, localVersion=updates.localVersion(),
            clientName=cfg.name, localServer=false, profile=resolvedProfile
        }
    end

    local function render(connected)
        if profile.render then profile.render(state, meta(connected)) end
    end

    local function publishNow()
        if not serverId then return false end
        local payload=helloPayload(); payload.state=localState
        network.send(serverId, cfg, "fleet.hello", helloPayload())
        return network.send(serverId, cfg, "telemetry.state", payload)
    end

    local function localDoorCommand(action, args)
        args = type(args) == "table" and args or {}
        if action ~= "register_local" and action ~= "remove_local" and
           tostring(args._source or "") ~= tostring(os.getComputerID()) then
            return false, "door is not owned by this computer"
        end
        local target = modules.doors
        if not target or type(target.handleCommand) ~= "function" then return false, "local door module unavailable" end
        local ok, result = pcall(target.handleCommand, action, args, localState.doors)
        localState = loader.readAll(modules, localState)
        publishNow()
        render(serverId ~= nil)
        return ok, result
    end

    local pollTimer = os.startTimer(0.1)
    local probationTimer = updates.hasPendingProbation() and os.startTimer(15) or nil

    while true do
        local e = { os.pullEvent() }

        if e[1] == "timer" and e[2] == pollTimer then
            if not serverId then serverId = network.findServer(cfg) end
            local now = os.epoch("utc")
            if now - lastModuleScan >= 10000 then modules=discoverModules(); lastModuleScan=now end
            localState = loader.readAll(modules, localState)

            if serverId then
                network.send(serverId, cfg, "fleet.hello", helloPayload())
                network.send(serverId, cfg, "state.get", helloPayload())
                local telemetry=helloPayload(); telemetry.state=localState
                network.send(serverId, cfg, "telemetry.state", telemetry)
            end

            render(serverId ~= nil)
            pollTimer = os.startTimer(1)

        elseif e[1] == "timer" and e[2] == probationTimer then
            if updates.markHealthy() then print("[KIMI] update probation passed; version marked healthy") end
            probationTimer=nil

        elseif e[1] == "rednet_message" then
            local sender,msg,protocol=e[2],e[3],e[4]
            if protocol==cfg.network.protocol and type(msg)=="table" then
                local payload=type(msg.payload)=="table" and msg.payload or {}
                if msg.kind=="fleet.probe" then
                    if not serverId then serverId=network.findServer(cfg) end
                    if sender==serverId then network.send(sender,cfg,"fleet.hello",helloPayload()) end

                elseif sender==serverId and msg.kind=="state" then
                    state=msg.payload; lastSeen=os.epoch("utc")
                    if profile.onState then profile.onState(state) end
                    render(true)

                elseif sender==serverId and msg.kind=="update.available" then
                    local target=tostring(payload.version or "")
                    if updates.fleetManaged(cfg) and target~="" and target~=updates.localVersion() then
                        network.send(serverId,cfg,"update.status",{role="client",version=updates.localVersion(),target=target,status="accepted"})
                        sleep((os.getComputerID()%4)+1)
                        updates.rebootForUpdate(target,"server-authority",payload.manifest)
                    end

                elseif sender==serverId and msg.kind=="module.command" then
                    local target=modules[payload.module]
                    local ok,result
                    if target and type(target.handleCommand)=="function" then
                        ok,result=pcall(target.handleCommand,payload.action,payload.args,localState[payload.module])
                    else ok,result=false,"unsupported module/action" end
                    localState=loader.readAll(modules,localState)
                    network.send(serverId,cfg,"module.command.result",{ok=ok,result=result,module=payload.module,action=payload.action,sourceId=os.getComputerID()})
                    publishNow(); render(true)
                end
            end

        elseif e[1]=="peripheral" or e[1]=="peripheral_detach" then
            network.openAll(); network.advertise(cfg,"client")
            serverId=network.findServer(cfg); modules=discoverModules(); localState=loader.readAll(modules,localState); lastModuleScan=os.epoch("utc")
            if profile.onPeripheralChange then profile.onPeripheralChange() end
            publishNow(); render(serverId~=nil)

        elseif profile.handleEvent then
            profile.handleEvent(e,state,function(module,action,args)
                if module=="__local_doors" then return localDoorCommand(action,args) end
                if serverId then return network.send(serverId,cfg,"command",{module=module,action=action,args=args}) end
                return false,"main server offline"
            end)
        end
    end
end

return M
