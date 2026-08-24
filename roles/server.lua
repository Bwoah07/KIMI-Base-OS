local M = {}
local network = require("core.network")
local loader = require("core.module_loader")
local updates = require("core.update_service")
local doorRegistry = require("core.door_registry")
local fleetRegistry = require("core.fleet_registry")

local function countTable(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
local function loadProfile(name)
    local ok,profile=pcall(require,"clients."..tostring(name or "admin"))
    if ok and type(profile)=="table" then return profile end
    return require("clients.terminal")
end
local function copyTable(src) local out={}; for k,v in pairs(src or {}) do out[k]=v end; return out end
local function healthRank(value)
    if type(value)~="table" then return 0 end
    local status=tostring(value._status or value.status or ""):lower()
    if value.online==true or status=="online" or status=="ok" or status=="running" then return 3 end
    if status=="error" then return 1 end
    if value.online==false or status=="offline" then return 0 end
    return 2
end
local function betterTelemetry(candidate,current)
    if not current then return true end
    local ch,oh=healthRank(candidate.value),healthRank(current.value)
    if ch~=oh then return ch>oh end
    return candidate.stamp>current.stamp
end

local function moduleValues(localState,sources,moduleId)
    local out={}
    if type(localState and localState[moduleId])=="table" then out[#out+1]={sourceId="server",value=localState[moduleId]} end
    for sourceId,source in pairs(sources or {}) do
        local value=source.online~=false and source.state and source.state[moduleId] or nil
        if type(value)=="table" then out[#out+1]={sourceId=tostring(sourceId),value=value} end
    end
    table.sort(out,function(a,b)return tostring(a.sourceId)<tostring(b.sourceId)end)
    return out
end
local function hasCategory(device,wanted)
    for _,category in ipairs(device and device.categories or {}) do if category==wanted then return true end end
    return false
end
local function aggregateAttachments(localState,sources)
    local devices,sensors,categories={},{},{}
    local values=moduleValues(localState,sources,"attachments")
    for _,source in ipairs(values) do
        for _,device in ipairs(source.value.devices or {}) do
            local item=copyTable(device); item._source=source.sourceId; devices[#devices+1]=item
            if hasCategory(item,"sensor") then sensors[#sensors+1]=item end
            for _,category in ipairs(item.categories or {}) do categories[category]=(categories[category] or 0)+1 end
        end
    end
    return {count=#devices,sensorCount=#sensors,devices=devices,sensors=sensors,categories=categories,sourceCount=#values,_status="online",_updated=os.epoch("utc")}
end
local function aggregateDoors(localState,sources,entries)
    return doorRegistry.snapshot(entries,doorRegistry.candidates(moduleValues(localState,sources,"doors")))
end
local function aggregatePower(primary,localState,sources)
    local out=copyTable(primary); local flux,matrices,detectors={},{},{}
    local function append(target,values,sourceId)
        for _,value in ipairs(values or {}) do local item=copyTable(value); item._source=sourceId; target[#target+1]=item end
    end
    for _,source in ipairs(moduleValues(localState,sources,"power")) do
        append(flux,source.value.fluxNetworks,source.sourceId); append(matrices,source.value.matrices,source.sourceId); append(detectors,source.value.energyDetectors,source.sourceId)
    end
    out.fluxNetworks=flux; out.matrices=matrices; out.energyDetectors=detectors
    out.fluxCount=#flux; out.matrixCount=#matrices; out.detectorCount=#detectors; out.onlineSources=#flux+#matrices+#detectors
    return out
end
local function canonicalState(localState,sources,machines,updateInfo,doorEntries)
    local combined=copyTable(localState); local selected={}
    for sourceId,source in pairs(sources or {}) do
        if source.online~=false then
            for moduleId,value in pairs(source.state or {}) do
                if type(value)=="table" then
                    local candidate={stamp=tonumber(value._updated) or tonumber(source.generated) or 0,value=value,sourceId=sourceId}
                    if betterTelemetry(candidate,selected[moduleId]) then selected[moduleId]=candidate end
                end
            end
        end
    end
    for moduleId,picked in pairs(selected) do
        local localValue=combined[moduleId]
        local localCandidate=localValue and {stamp=tonumber(localValue._updated) or 0,value=localValue,sourceId="server"} or nil
        if not localCandidate or betterTelemetry(picked,localCandidate) then local chosen=copyTable(picked.value); chosen._source=picked.sourceId; combined[moduleId]=chosen
        elseif type(localValue)=="table" then local chosen=copyTable(localValue); chosen._source="server"; combined[moduleId]=chosen end
    end
    combined.attachments=aggregateAttachments(localState,sources)
    combined.doors=aggregateDoors(localState,sources,doorEntries)
    combined.power=aggregatePower(combined.power or {},localState,sources)
    combined.sources=sources; combined.fleet=machines; combined.update=updateInfo
    return combined
end
local function makeEnvelope(localState,sources,machines,updateInfo,doorEntries)
    return {schema=3,serverId=os.getComputerID(),version=updates.localVersion(),generated=os.epoch("utc"),state=canonicalState(localState,sources,machines,updateInfo,doorEntries)}
end

function M.run(cfg)
    network.host(cfg)
    local modules=loader.discover("modules")
    local state=loader.readAll(modules,{})
    local machines=fleetRegistry.load()
    local sources={}
    local doorEntries=doorRegistry.load()
    local lastModuleScan=os.epoch("utc")
    local startedAt=os.epoch("utc")
    local selfId=os.getComputerID()
    machines[selfId]={firstSeen=startedAt,lastSeen=startedAt,role="server",name=cfg.name,profile="admin",version=updates.localVersion(),online=true,updateStatus="current"}
    for id,m in pairs(machines) do if tonumber(id)~=selfId then m.online=false end end
    fleetRegistry.save(machines)

    local updateInfo={authority=selfId,lastCheck=nil,lastResult="not checked",remoteVersion=nil,targetVersion=nil,fleetTarget=updates.localVersion(),fleetCurrent=1,fleetOutdated=0,fleetOffline=0,lastSync=nil,syncResult="discovering fleet",discovered=0}
    local profile=nil
    if cfg.localUI then profile=loadProfile("admin"); if profile.init then profile.init(cfg) end end

    local function saveFleet() fleetRegistry.save(machines) end

    local function executeCommand(moduleId,action,args)
        args=type(args)=="table" and args or {}
        if moduleId=="doors" and action=="register" then
            local snapshot=aggregateDoors(state,sources,doorEntries)
            local entry,err=doorRegistry.add(doorEntries,snapshot.candidates,args.key)
            if not entry then return {ok=false,error=err,module=moduleId} end
            doorRegistry.save(doorEntries); return {ok=true,result=entry,module=moduleId}
        elseif moduleId=="doors" and action=="remove" then
            local entry,err=doorRegistry.remove(doorEntries,args.id)
            if not entry then return {ok=false,error=err,module=moduleId} end
            doorRegistry.save(doorEntries); return {ok=true,result=entry,module=moduleId}
        end
        local sourceId=args._source
        if sourceId and tostring(sourceId)~="server" and tostring(sourceId)~=tostring(selfId) then
            local targetId=tonumber(sourceId); local source=targetId and sources[tostring(targetId)] or nil
            if not targetId or not source or source.online==false then return {ok=false,error="target telemetry node is offline",module=moduleId} end
            local sent=network.send(targetId,cfg,"module.command",{module=moduleId,action=action,args=args,issuedBy=selfId})
            return {ok=sent==true,result={queued=sent==true,sourceId=targetId},module=moduleId}
        end
        local target=modules[moduleId]
        if target and type(target.handleCommand)=="function" then local ok,result=pcall(target.handleCommand,action,args,state[moduleId]); return {ok=ok,result=result,module=moduleId} end
        return {ok=false,error="unsupported module/action",module=moduleId}
    end

    local function env() return makeEnvelope(state,sources,machines,updateInfo,doorEntries) end
    local function renderLocal()
        if profile and profile.render then profile.render(env(),{connected=true,lastSeen=os.epoch("utc"),serverId=selfId,localServer=true,startedAt=startedAt,machines=machines,sources=sources,update=updateInfo,localState=state}) end
    end

    local function requestScadaUpdates(reason)
        local requested,skipped=0,0
        for sourceId,source in pairs(sources) do
            if source.online~=false and source.role=="scada" then
                local needs=false
                for _,value in pairs(source.state or {}) do if type(value)=="table" and value.updateAvailable==true then needs=true; break end end
                if needs then
                    local target=tonumber(sourceId) or tonumber(source.sourceId)
                    if target and network.send(target,cfg,"scada.update.request",{issuedBy=selfId,reason=reason or "command-center",requested=os.epoch("utc")}) then requested=requested+1 end
                else skipped=skipped+1 end
            end
        end
        return {requested=requested,current=skipped}
    end

    local function offerCatchup(sender,machine)
        if not machine or machine.role=="scada" or tonumber(sender)==selfId then return end
        local target=updates.localVersion()
        if machine.version~=target then
            local sent=network.send(sender,cfg,"update.available",{version=target,issuedBy=selfId,reason="fleet-authority"})
            machine.updateTarget=target; machine.updateStatus=sent and "notified" or "send failed"
        else machine.updateTarget=nil; machine.updateStatus="current" end
    end

    local function touchMachine(sender,payload,defaultRole)
        sender=tonumber(sender) or sender
        local now=os.epoch("utc"); local m=machines[sender] or {firstSeen=now}
        m.lastSeen=now; m.online=true
        m.role=payload and payload.role or m.role or defaultRole or "client"
        m.name=payload and payload.name or m.name or ("KIMI-"..tostring(sender))
        m.profile=payload and payload.profile or m.profile
        m.version=payload and payload.version or m.version
        machines[sender]=m; offerCatchup(sender,m); saveFleet(); return m
    end

    local function probeFleet()
        local seen={}
        for _,id in ipairs(network.lookupAll(cfg)) do seen[id]=true end
        for id,m in pairs(machines) do if tonumber(id)~=selfId then seen[tonumber(id) or id]=true end end
        local probed=0
        for id in pairs(seen) do
            if tonumber(id) and tonumber(id)~=selfId then
                local sent=network.send(tonumber(id),cfg,"fleet.probe",{serverId=selfId,version=updates.localVersion(),hostname=cfg.network.hostname})
                if sent then probed=probed+1 end
            end
        end
        updateInfo.discovered=probed
        return probed
    end

    local function syncFleet(reason,visible)
        probeFleet()
        local target=updates.localVersion(); local current,outdated,offline,notified=0,0,0,0
        for id,machine in pairs(machines) do
            if tonumber(id)==selfId then current=current+1; machine.online=true; machine.version=target; machine.updateStatus="current"
            elseif machine.role~="scada" then
                if machine.online==false then offline=offline+1
                elseif machine.version==target then current=current+1; machine.updateTarget=nil; machine.updateStatus="current"
                else
                    outdated=outdated+1
                    local sent=network.send(tonumber(id),cfg,"update.available",{version=target,issuedBy=selfId,reason=reason or "fleet-sync"})
                    machine.updateTarget=target; machine.updateStatus=sent and "notified" or "send failed"; if sent then notified=notified+1 end
                end
            end
        end
        updateInfo.fleetTarget=target; updateInfo.fleetCurrent=current; updateInfo.fleetOutdated=outdated; updateInfo.fleetOffline=offline; updateInfo.lastSync=os.epoch("utc")
        updateInfo.syncResult=tostring(current).." current / "..tostring(notified).." notified / "..tostring(offline).." offline"
        saveFleet(); if visible~=false then renderLocal() end
        return {target=target,current=current,outdated=outdated,notified=notified,offline=offline}
    end

    local function checkForUpdates(reason)
        if not updates.autoEnabled(cfg) then updateInfo.lastCheck=os.epoch("utc"); updateInfo.lastResult="updates disabled"; renderLocal(); return false end
        updateInfo.lastCheck=os.epoch("utc"); updateInfo.lastResult="checking..."; renderLocal()
        local result,err=updates.check()
        if not result then updateInfo.lastResult="check failed: "..tostring(err); renderLocal(); return false end
        updateInfo.remoteVersion=result.remote; updateInfo.lastResult=result.available and "update available" or "up to date"; updateInfo.targetVersion=result.available and result.remote or nil; renderLocal()
        if not result.available then return false end
        -- Authority installs first. Only after the probation reboot does normal
        -- fleet sync push this exact installed manifest to every machine.
        updates.rebootForUpdate(result.remote,reason or "server-check",result.manifest)
        return true
    end

    print("KIMI Base Server online - ID "..selfId)
    print("Version: "..updates.localVersion())
    print("Modules: "..tostring(countTable(modules)))
    if cfg.localUI then print("Command-center admin UI: enabled") end

    local refreshTimer=os.startTimer(0.5)
    local updateTimer=os.startTimer(updates.interval(cfg))
    local fleetSyncTimer=os.startTimer(2)
    local probationTimer=updates.hasPendingProbation() and os.startTimer(15) or nil

    while true do
        local e={os.pullEvent()}
        if e[1]=="timer" and e[2]==refreshTimer then
            state=loader.readAll(modules,state); local now=os.epoch("utc")
            if now-lastModuleScan>=10000 then modules=loader.discover("modules"); lastModuleScan=now end
            for id,m in pairs(machines) do if tonumber(id)~=selfId then m.online=(now-(tonumber(m.lastSeen) or 0))<=15000 end end
            for _,s in pairs(sources) do s.online=(now-(tonumber(s.lastSeen) or 0))<=15000 end
            renderLocal(); refreshTimer=os.startTimer(0.5)

        elseif e[1]=="timer" and e[2]==probationTimer then
            if updates.markHealthy() then print("[KIMI] update probation passed; version marked healthy") end
            probationTimer=nil; syncFleet("post-probation",false)

        elseif e[1]=="timer" and e[2]==updateTimer then
            checkForUpdates("server-periodic-check"); updateTimer=os.startTimer(updates.interval(cfg))

        elseif e[1]=="timer" and e[2]==fleetSyncTimer then
            syncFleet("server-auto-sync",false); fleetSyncTimer=os.startTimer(5)

        elseif e[1]=="rednet_message" then
            local sender,msg,protocol=e[2],e[3],e[4]
            if protocol==cfg.network.protocol and type(msg)=="table" then
                local payload=type(msg.payload)=="table" and msg.payload or {}
                if msg.kind=="fleet.hello" then touchMachine(sender,payload,payload.role or "client")
                elseif msg.kind=="state.get" then touchMachine(sender,payload,"client"); network.send(sender,cfg,"state",env())
                elseif msg.kind=="telemetry.state" or msg.kind=="node.state" then
                    local m=touchMachine(sender,payload,msg.kind=="node.state" and "node" or "client")
                    sources[tostring(sender)]={sourceId=payload.sourceId or payload.nodeId or sender,role=payload.role or m.role,name=payload.name or m.name,profile=payload.profile or m.profile,version=payload.version or m.version,generated=payload.generated,lastSeen=os.epoch("utc"),online=true,state=payload.state or {}}
                elseif msg.kind=="ping" then touchMachine(sender,payload,payload.role or "client"); network.send(sender,cfg,"pong",{serverId=selfId,version=updates.localVersion()})
                elseif msg.kind=="command" then
                    touchMachine(sender,payload,"client"); local result
                    if payload.module=="doors" then result={ok=false,error="door controls are restricted to the local Command Center",module="doors"}
                    elseif payload.module=="server" and payload.action=="scada_update" then result={ok=true,result=requestScadaUpdates("remote-command"),module="server"}
                    else result=executeCommand(payload.module,payload.action,payload.args) end
                    network.send(sender,cfg,"command.result",result)
                elseif msg.kind=="update.status" then
                    local m=touchMachine(sender,payload,payload.role or "client"); m.version=payload.version or m.version; m.updateTarget=payload.target; m.updateStatus=payload.status; saveFleet()
                end
            end

        elseif e[1]=="peripheral" or e[1]=="peripheral_detach" then
            network.openAll(); modules=loader.discover("modules"); state=loader.readAll(modules,state)
            if profile and profile.onPeripheralChange then profile.onPeripheralChange() end
            probeFleet(); renderLocal()

        elseif profile and profile.handleEvent then
            profile.handleEvent(e,env(),function(moduleId,action,args)
                if moduleId=="server" and action=="check_updates" then return checkForUpdates("server-manual-check")
                elseif moduleId=="server" and action=="scada_update" then return requestScadaUpdates("command-center")
                elseif moduleId=="server" and action=="sync_fleet" then return syncFleet("command-center",true) end
                return executeCommand(moduleId,action,args)
            end)
        end
    end
end

return M
