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
    if ok and type(profile) == "table" then return profile, resolved, nil end
    local fallbackOk, fallback = pcall(require, "clients.terminal")
    if fallbackOk and type(fallback) == "table" then return fallback, "terminal", profile end
    error("unable to load UI profile " .. tostring(resolved) .. ": " .. tostring(profile))
end

local function discoverModules() return loader.discover("modules") end

local function paintUiError(err)
    local msg = tostring(err or "unknown UI error")
    local names = {}
    local okNames, rawNames = pcall(peripheral.getNames)
    if okNames and type(rawNames) == "table" then names = rawNames end
    for _, name in ipairs(names) do
        local isMon = false
        local okType, t = pcall(peripheral.getType, name)
        if okType and t == "monitor" then isMon = true end
        if not isMon and type(peripheral.hasType) == "function" then
            local okHas, has = pcall(peripheral.hasType, name, "monitor")
            isMon = okHas and has == true
        end
        if isMon then
            local okWrap, mon = pcall(peripheral.wrap, name)
            if okWrap and mon then
                pcall(mon.setTextScale, 1)
                pcall(mon.setBackgroundColor, colors.black)
                pcall(mon.setTextColor, colors.red)
                pcall(mon.clear)
                pcall(mon.setCursorPos, 2, 2)
                pcall(mon.write, "KIMI UI ERROR")
                pcall(mon.setTextColor, colors.white)
                local okSize, w, h = pcall(mon.getSize)
                w, h = okSize and tonumber(w) or 40, okSize and tonumber(h) or 20
                local width = math.max(8, w - 2)
                for i = 1, math.min(5, math.ceil(#msg / width)) do
                    local part = msg:sub((i - 1) * width + 1, i * width)
                    pcall(mon.setCursorPos, 2, 3 + i)
                    pcall(mon.write, part)
                end
            end
        end
    end
    if not fs.exists(".kimi") then pcall(fs.makeDir, ".kimi") end
    if not fs.exists(".kimi/logs") then pcall(fs.makeDir, ".kimi/logs") end
    local f = fs.open(".kimi/logs/ui-error.log", "a")
    if f then f.writeLine(tostring(os.epoch("utc")) .. " " .. msg); f.close() end
end

function M.run(cfg)
    network.openAll()
    network.advertise(cfg, "client")
    local profile, resolvedProfile, profileLoadErr = loadProfile(cfg.profile)
    local modules = discoverModules()
    local localState = loader.readAll(modules, {})
    local serverId, state, lastSeen = nil, nil, 0
    local lastModuleScan = os.epoch("utc")

    if profileLoadErr then paintUiError("profile load failed: " .. tostring(profileLoadErr)) end
    if profile.init then
        local ok, err = pcall(profile.init, cfg)
        if not ok then paintUiError("profile init failed: " .. tostring(err)) end
    end

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
        if not profile.render then return true end
        local ok, result = pcall(profile.render, state, meta(connected))
        if not ok then paintUiError(result); return false, result end
        if result == false then return false end
        return true
    end

    local function publishNow()
        if not serverId then return false end
        local payload=helloPayload(); payload.state=localState
        network.send(serverId, cfg, "fleet.hello", helloPayload())
        return network.send(serverId, cfg, "telemetry.state", payload)
    end

    local function methodSet(name)
        local out={}
        if not peripheral or type(peripheral.getMethods)~="function" then return out end
        local ok,list=pcall(peripheral.getMethods,name)
        if ok and type(list)=="table" then for _,m in ipairs(list) do out[m]=true end end
        return out
    end

    local function currentLocalDoor(args)
        local doors=localState and localState.doors and localState.doors.localDoors or {}
        for _,d in ipairs(doors or {}) do
            if tostring(d.target or "")==tostring(args.target or "") and tostring(d.side or "")==tostring(args.side or "") then return d end
        end
        return nil
    end

    local function directLocalRedstone(action,args)
        local target=tostring(args.target or "")
        local side=args.side~=nil and tostring(args.side) or nil
        local d=currentLocalDoor(args)
        local mode=tostring((d and d.mode) or "hold")
        if action~="toggle" and action~="open" and action~="close" and action~="pulse" then return nil end

        local function desiredFrom(current)
            if action=="open" then return true end
            if action=="close" then return false end
            if action=="toggle" then return not current end
            return true
        end
        local function logicalFromPhysical(physical)
            if mode=="invert" then return not (physical==true) end
            return physical==true
        end
        local function physicalFromLogical(logical)
            if mode=="invert" then return not (logical==true) end
            return logical==true
        end

        if target=="computer" then
            if type(redstone)~="table" or type(redstone.setOutput)~="function" then return false,"computer redstone unavailable" end
            local okRead,current=pcall(redstone.getOutput,side)
            if not okRead then current=d and d.signal==true or false end
            if action=="pulse" or mode=="pulse" then
                local ok,err=pcall(redstone.setOutput,side,true); if not ok then return false,"redstone ON failed: "..tostring(err) end
                sleep(math.max(.05,math.min(5,tonumber(d and d.pulseSeconds) or .5)))
                ok,err=pcall(redstone.setOutput,side,false); if not ok then return false,"redstone OFF failed: "..tostring(err) end
                return true,{target=target,side=side,signal=false,open=false,action="pulse",direct=true}
            end
            local desired=desiredFrom(logicalFromPhysical(current==true))
            local physical=physicalFromLogical(desired)
            local ok,err=pcall(redstone.setOutput,side,physical)
            if not ok then return false,"redstone write failed: "..tostring(err) end
            return true,{target=target,side=side,signal=physical,open=desired,action=action,direct=true}
        end

        if target~="" and peripheral and type(peripheral.call)=="function" then
            local methods=methodSet(target)
            if methods.setOutput then
                local current=d and d.signal==true or false
                if methods.getOutput then local ok,v=pcall(peripheral.call,target,"getOutput",side); if ok then current=v==true end end
                if action=="pulse" or mode=="pulse" then
                    local ok,err=pcall(peripheral.call,target,"setOutput",side,true); if not ok then return false,"integrator ON failed: "..tostring(err) end
                    sleep(math.max(.05,math.min(5,tonumber(d and d.pulseSeconds) or .5)))
                    ok,err=pcall(peripheral.call,target,"setOutput",side,false); if not ok then return false,"integrator OFF failed: "..tostring(err) end
                    return true,{target=target,side=side,signal=false,open=false,action="pulse",direct=true}
                end
                local desired=desiredFrom(logicalFromPhysical(current==true))
                local physical=physicalFromLogical(desired)
                local ok,err=pcall(peripheral.call,target,"setOutput",side,physical)
                if not ok then return false,"integrator write failed: "..tostring(err) end
                return true,{target=target,side=side,signal=physical,open=desired,action=action,direct=true}
            end
        end
        return nil
    end

    local function localDoorCommand(action, args)
        args = type(args) == "table" and args or {}
        if action ~= "register_local" and action ~= "remove_local" and
           tostring(args._source or "") ~= tostring(os.getComputerID()) then
            return false, "door is not owned by this computer"
        end

        local directOk,directResult=directLocalRedstone(action,args)
        if directOk~=nil then
            localState=loader.readAll(modules,localState)
            publishNow(); render(serverId~=nil)
            return directOk,directResult
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
                    if profile.onState then
                        local okState, stateErr = pcall(profile.onState, state)
                        if not okState then paintUiError("onState failed: " .. tostring(stateErr)) end
                    end
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
                    if payload.module=="doors" then
                        ok,result=localDoorCommand(payload.action,payload.args)
                    elseif target and type(target.handleCommand)=="function" then
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
            if profile.onPeripheralChange then
                local okPer, perErr = pcall(profile.onPeripheralChange)
                if not okPer then paintUiError("peripheral refresh failed: " .. tostring(perErr)) end
            end
            publishNow(); render(serverId~=nil)

        elseif profile.handleEvent then
            local okEvent, eventErr = pcall(profile.handleEvent,e,state,function(module,action,args)
                if module=="__local_doors" then return localDoorCommand(action,args) end
                if serverId then return network.send(serverId,cfg,"command",{module=module,action=action,args=args}) end
                return false,"main server offline"
            end)
            if not okEvent then paintUiError("UI event failed: " .. tostring(eventErr)) end
        end
    end
end

return M
