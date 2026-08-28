local M = {}
local network = require("core.network")
local loader = require("core.module_loader")
local updates = require("core.update_service")
local doorRegistry = require("core.door_registry")
local fleetRegistry = require("core.fleet_registry")
local fleetHealth = require("core.fleet_health")
local telemetryHealth = require("core.telemetry_health")

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
    local ct,ot=tonumber(candidate.telemetryRank)or 0,tonumber(current.telemetryRank)or 0
    if ct~=ot then return ct>ot end
    return candidate.stamp>current.stamp
end

local function moduleValues(localState,sources,moduleId)
    local out={}
    if type(localState and localState[moduleId])=="table" then
        out[#out+1]={sourceId="server",value=localState[moduleId],telemetryStatus="LIVE",telemetryAgeMs=0,connected=true}
    end
    for sourceId,source in pairs(sources or {}) do
        local value=telemetryHealth.usable(source.telemetryStatus)and source.state and source.state[moduleId]or nil
        if type(value)=="table" then
            out[#out+1]={
                sourceId=tostring(sourceId),value=value,
                telemetryStatus=source.telemetryStatus,
                telemetryAgeMs=source.telemetryAgeMs,
                connected=source.online==true,
            }
        end
    end
    table.sort(out,function(a,b)return tostring(a.sourceId)<tostring(b.sourceId)end)
    return out
end
local function hasCategory(device,wanted)
    for _,category in ipairs(device and device.categories or {}) do if category==wanted then return true end end
    return false
end
local function aggregateAttachments(localState,sources)
    local devices,sensors,categories={},{},{};local liveDevices,cachedDevices=0,0
    local values=moduleValues(localState,sources,"attachments")
    for _,source in ipairs(values) do
        for _,device in ipairs(source.value.devices or {}) do
            local item=copyTable(device);item._source=source.sourceId;item._telemetryStatus=source.telemetryStatus;item._telemetryAgeMs=source.telemetryAgeMs;item._connected=source.connected;devices[#devices+1]=item
            if source.telemetryStatus=="LIVE"then liveDevices=liveDevices+1 elseif source.telemetryStatus=="CACHED"then cachedDevices=cachedDevices+1 end
            if hasCategory(item,"sensor") or hasCategory(item,"sensor_candidate") then sensors[#sensors+1]=item end
            for _,category in ipairs(item.categories or {}) do categories[category]=(categories[category] or 0)+1 end
        end
    end
    return {count=#devices,sensorCount=#sensors,devices=devices,sensors=sensors,categories=categories,sourceCount=#values,liveDevices=liveDevices,cachedDevices=cachedDevices,_status=liveDevices>0 and"online"or(cachedDevices>0 and"cached"or"offline"),_updated=os.epoch("utc")}
end
local function aggregateDoors(localState,sources,entries)
    return doorRegistry.snapshot(entries,doorRegistry.candidates(moduleValues(localState,sources,"doors")))
end
local function aggregatePower(primary,localState,sources)
    local out=copyTable(primary); local flux,matrices,detectors={},{},{}
    local function append(target,values,source)
        for _,value in ipairs(values or {}) do local item=copyTable(value);item._source=source.sourceId;item._telemetryStatus=source.telemetryStatus;item._telemetryAgeMs=source.telemetryAgeMs;item._connected=source.connected;target[#target+1]=item end
    end
    for _,source in ipairs(moduleValues(localState,sources,"power")) do
        append(flux,source.value.fluxNetworks,source);append(matrices,source.value.matrices,source);append(detectors,source.value.energyDetectors,source)
    end
    out.fluxNetworks=flux; out.matrices=matrices; out.energyDetectors=detectors
    out.fluxCount=#flux;out.matrixCount=#matrices;out.detectorCount=#detectors
    local live,cached=0,0;for _,list in ipairs({flux,matrices,detectors})do for _,item in ipairs(list)do if item._telemetryStatus=="LIVE"then live=live+1 elseif item._telemetryStatus=="CACHED"then cached=cached+1 end end end
    out.onlineSources=live;out.cachedSources=cached;out.telemetrySources=live+cached
    return out
end
local function aggregateBuilders(localState,sources)
    local builders={};local live,cached=0,0
    for _,source in ipairs(moduleValues(localState,sources,"builder")) do
        for _,b in ipairs(source.value.builders or {}) do local item=copyTable(b);item._source=source.sourceId;item._telemetryStatus=source.telemetryStatus;item._telemetryAgeMs=source.telemetryAgeMs;item._connected=source.connected;builders[#builders+1]=item;if source.telemetryStatus=="LIVE"then live=live+1 elseif source.telemetryStatus=="CACHED"then cached=cached+1 end end
    end
    table.sort(builders,function(a,b)return tostring(a.peripheral or a.type)<tostring(b.peripheral or b.type)end)
    return {builders=builders,count=#builders,liveCount=live,cachedCount=cached,_status=live>0 and"online"or(cached>0 and"cached"or"offline"),_updated=os.epoch("utc")}
end
local function canonicalState(localState,sources,machines,updateInfo,doorEntries)
    local combined=copyTable(localState); local selected={}
    for sourceId,source in pairs(sources or {}) do
        if telemetryHealth.usable(source.telemetryStatus) then
            for moduleId,value in pairs(source.state or {}) do
                if type(value)=="table" then
                    local candidate={stamp=tonumber(value._updated)or tonumber(source.generated)or 0,value=value,sourceId=sourceId,telemetryRank=telemetryHealth.rank(source.telemetryStatus),telemetryStatus=source.telemetryStatus,telemetryAgeMs=source.telemetryAgeMs,connected=source.online==true}
                    if betterTelemetry(candidate,selected[moduleId]) then selected[moduleId]=candidate end
                end
            end
        end
    end
    for moduleId,picked in pairs(selected) do
        local localValue=combined[moduleId]
        local localCandidate=localValue and {stamp=tonumber(localValue._updated)or 0,value=localValue,sourceId="server",telemetryRank=4,telemetryStatus="LIVE",telemetryAgeMs=0,connected=true}or nil
        if not localCandidate or betterTelemetry(picked,localCandidate) then local chosen=copyTable(picked.value);chosen._source=picked.sourceId;chosen._telemetryStatus=picked.telemetryStatus;chosen._telemetryAgeMs=picked.telemetryAgeMs;chosen._connected=picked.connected;combined[moduleId]=chosen
        elseif type(localValue)=="table" then local chosen=copyTable(localValue);chosen._source="server";chosen._telemetryStatus="LIVE";chosen._telemetryAgeMs=0;chosen._connected=true;combined[moduleId]=chosen end
    end
    combined.attachments=aggregateAttachments(localState,sources)
    combined.doors=aggregateDoors(localState,sources,doorEntries)
    combined.power=aggregatePower(combined.power or {},localState,sources)
    combined.builder=aggregateBuilders(localState,sources)
    combined.sources=sources; combined.fleet=machines; combined.update=updateInfo
    return combined
end
local function makeEnvelope(localState,sources,machines,updateInfo,doorEntries)
    return {schema=3,serverId=os.getComputerID(),version=updates.localVersion(),generated=os.epoch("utc"),state=canonicalState(localState,sources,machines,updateInfo,doorEntries)}
end

local function applyReachability(id,record,serverId,now,seen)
    record=record or{}
    local probe={lastSeen=tonumber(seen) or tonumber(record.lastSeen),ageMs=record.ageMs}
    local status,age=fleetHealth.reachability(id,probe,serverId,now)
    record.ageMs=age
    record.presence=status
    record.stale=status=="LATE"
    record.online=status=="ONLINE"
    return status,age
end

local function applySourceHealth(id,source,serverId,now)
    local presence=applyReachability(id,source,serverId,now,source.lastHeartbeat or source.lastSeen)
    local dataStatus,dataAge=telemetryHealth.status(source,presence,now)
    source.telemetryStatus=dataStatus
    source.telemetryAgeMs=dataAge
    source.dataAvailable=telemetryHealth.usable(dataStatus)
    source.connected=source.online==true
    return dataStatus,dataAge
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
    machines[selfId]={firstSeen=startedAt,lastSeen=startedAt,role="server",name=cfg.name,profile="admin",version=updates.localVersion(),online=true,stale=false,presence="ONLINE",updateStatus="current"}
    for id,m in pairs(machines) do if tonumber(id)~=selfId then m.online=false;m.stale=false;m.presence="OFFLINE" end end
    fleetRegistry.save(machines)

    local updateInfo={authority=selfId,lastCheck=nil,lastResult="not checked",remoteVersion=nil,targetVersion=nil,fleetTarget=updates.localVersion(),fleetCurrent=1,fleetOutdated=0,fleetOffline=0,lastSync=nil,syncResult="discovering fleet",discovered=0}
    local profile=nil
    if cfg.localUI then profile=loadProfile("admin"); if profile.init then profile.init(cfg) end end

    local fleetDirty=false
    local lastFleetSave=startedAt
    local lastFleetProbe=-math.huge
    local FLEET_PROBE_MS=30000
    local function saveFleet(force)
        fleetDirty=true
        local now=os.epoch("utc")
        if force or now-lastFleetSave>=10000 then
            fleetRegistry.save(machines);fleetDirty=false;lastFleetSave=now
        end
    end

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
            if not targetId or not source or source.online~=true then return {ok=false,error="target telemetry node is offline",module=moduleId} end
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
            if source.online==true and source.role=="scada" then
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

    local function offerCatchup(sender,machine,force,reason)
        if not machine or machine.role=="scada" or tonumber(sender)==selfId then return end
        local target=updates.localVersion()
        if machine.version~=target then
            local now=os.epoch("utc")
            if not force and tonumber(machine.nextUpdateOffer)and now<tonumber(machine.nextUpdateOffer)then return false,"backoff"end
            local attempts=(tonumber(machine.updateAttempts)or 0)+1
            local delay=math.min(60000,5000*(2^math.min(4,attempts-1)))
            local sent=network.send(sender,cfg,"update.available",{version=target,issuedBy=selfId,reason=reason or"fleet-authority"})
            machine.updateTarget=target;machine.updateAttempts=attempts;machine.lastUpdateOffer=now;machine.nextUpdateOffer=now+delay
            machine.updateStatus=sent and("notified #"..attempts)or("send failed #"..attempts)
            return sent==true,sent and"notified"or"failed"
        else
            machine.updateTarget=nil;machine.updateStatus="current";machine.updateAttempts=0;machine.nextUpdateOffer=nil
            return false,"current"
        end
    end

    local function touchMachine(sender,payload,defaultRole)
        sender=tonumber(sender) or sender
        local now=os.epoch("utc"); local m=machines[sender] or {firstSeen=now}
        m.lastSeen=now; m.online=true; m.stale=false; m.presence="ONLINE"; m.ageMs=0
        m.role=payload and payload.role or m.role or defaultRole or "client"
        m.name=payload and payload.name or m.name or ("KIMI-"..tostring(sender))
        m.profile=payload and payload.profile or m.profile
        m.version=payload and payload.version or m.version
        local source=sources[tostring(sender)]
        if source then source.lastHeartbeat=now;applySourceHealth(sender,source,selfId,now)end
        machines[sender]=m;offerCatchup(sender,m,false,"heartbeat");saveFleet(false);return m
    end

    local function probeFleet(force)
        local now=os.epoch("utc")
        if not force and now-lastFleetProbe<FLEET_PROBE_MS then return 0 end
        lastFleetProbe=now
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
        probeFleet(reason=="command-center")
        local target=updates.localVersion(); local current,outdated,offline,notified=0,0,0,0
        for id,machine in pairs(machines) do
            if tonumber(id)==selfId then current=current+1; machine.online=true;machine.stale=false;machine.presence="ONLINE"; machine.version=target; machine.updateStatus="current"
            elseif machine.role~="scada" then
                if machine.online~=true then offline=offline+1
                elseif machine.version==target then current=current+1; machine.updateTarget=nil; machine.updateStatus="current"
                else
                    outdated=outdated+1
                    local sent=offerCatchup(tonumber(id),machine,reason=="command-center",reason or"fleet-sync")
                    if sent then notified=notified+1 end
                end
            end
        end
        updateInfo.fleetTarget=target; updateInfo.fleetCurrent=current; updateInfo.fleetOutdated=outdated; updateInfo.fleetOffline=offline; updateInfo.lastSync=os.epoch("utc")
        updateInfo.syncResult=tostring(current).." current / "..tostring(notified).." notified / "..tostring(offline).." offline"
        saveFleet(false); if visible~=false then renderLocal() end
        return {target=target,current=current,outdated=outdated,notified=notified,offline=offline}
    end

    local function identifyMachine(args)
        args=type(args)=="table"and args or{};local id=tonumber(args.id)
        if not id then return {ok=false,error="computer id required",module="server"} end
        if id==selfId then return {ok=false,error="that is Main Base itself",module="server"} end
        local m=machines[id];if not m then return {ok=false,error="unknown fleet computer",module="server"} end
        local sent=network.send(id,cfg,"fleet.identify",{duration=tonumber(args.duration)or 8,issuedBy=selfId,name=m.name,id=id})
        return {ok=sent==true,result={id=id,name=m.name,sent=sent==true},module="server"}
    end

    local function checkForUpdates(reason)
        if not updates.autoEnabled(cfg) then updateInfo.lastCheck=os.epoch("utc"); updateInfo.lastResult="updates disabled"; renderLocal(); return false end
        updateInfo.lastCheck=os.epoch("utc"); updateInfo.lastResult="checking..."; renderLocal()
        local result,err=updates.check()
        if not result then updateInfo.lastResult="check failed: "..tostring(err); renderLocal(); return false end
        updateInfo.remoteVersion=result.remote; updateInfo.lastResult=result.available and "update available" or "up to date"; updateInfo.targetVersion=result.available and result.remote or nil; renderLocal()
        if not result.available then return false end
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
            for id,m in pairs(machines) do
                if tonumber(id)~=selfId then applyReachability(id,m,selfId,now,m.lastSeen) end
            end
            for id,s in pairs(sources) do
                applySourceHealth(id,s,selfId,now)
            end
            if fleetDirty then saveFleet(false)end
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
                    local seen=os.epoch("utc")
                    sources[tostring(sender)]={sourceId=payload.sourceId or payload.nodeId or sender,role=payload.role or m.role,name=payload.name or m.name,profile=payload.profile or m.profile,version=payload.version or m.version,generated=payload.generated,lastSeen=seen,lastTelemetry=seen,lastHeartbeat=seen,online=true,connected=true,stale=false,presence="ONLINE",telemetryStatus="LIVE",telemetryAgeMs=0,dataAvailable=true,state=payload.state or {}}
                elseif msg.kind=="ping" then touchMachine(sender,payload,payload.role or "client"); network.send(sender,cfg,"pong",{serverId=selfId,version=updates.localVersion()})
                elseif msg.kind=="command" then
                    touchMachine(sender,payload,"client"); local result
                    if payload.module=="doors" then result={ok=false,error="door controls are restricted to the local Command Center",module="doors"}
                    elseif payload.module=="server" and payload.action=="scada_update" then result={ok=true,result=requestScadaUpdates("remote-command"),module="server"}
                    else result=executeCommand(payload.module,payload.action,payload.args) end
                    network.send(sender,cfg,"command.result",result)
                elseif msg.kind=="update.status" then
                    local m=touchMachine(sender,payload,payload.role or "client");m.version=payload.version or m.version;m.updateTarget=payload.target;m.updateStatus=payload.status
                    if tostring(payload.status or""):lower()=="accepted"then m.nextUpdateOffer=os.epoch("utc")+120000 end
                    saveFleet(true)
                end
            end

        elseif e[1]=="peripheral" or e[1]=="peripheral_detach" then
            network.openAll(); modules=loader.discover("modules"); state=loader.readAll(modules,state)
            if profile and profile.onPeripheralChange then profile.onPeripheralChange() end
            probeFleet(true); renderLocal()

        elseif profile and profile.handleEvent then
            profile.handleEvent(e,env(),function(moduleId,action,args)
                if moduleId=="server" and action=="check_updates" then return checkForUpdates("server-manual-check")
                elseif moduleId=="server" and action=="scada_update" then return requestScadaUpdates("command-center")
                elseif moduleId=="server" and action=="sync_fleet" then return syncFleet("command-center",true)
                elseif moduleId=="server" and action=="identify" then return identifyMachine(args) end
                return executeCommand(moduleId,action,args)
            end)
        end
    end
end

return M
