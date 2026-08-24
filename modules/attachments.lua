local M = { id = "attachments" }

local function safeCall(obj, method, fallback, ...)
    if not obj or type(obj[method]) ~= "function" then return fallback, false end
    local ok, value = pcall(obj[method], ...)
    if not ok or value == nil then return fallback, false end
    return value, true
end

local function norm(v) return tostring(v or ""):lower():gsub("[^a-z0-9]", "") end
local function has(text, needle) return norm(text):find(norm(needle), 1, true) ~= nil end
local function countTable(t) local n=0; if type(t)=="table" then for _ in pairs(t) do n=n+1 end end; return n end

local function getTypes(name)
    local raw = { pcall(peripheral.getType, name) }
    if not raw[1] then return { "unknown" } end
    table.remove(raw, 1)
    local out, seen = {}, {}
    for _, v in ipairs(raw) do
        if type(v) == "string" and not seen[v] then seen[v]=true; out[#out+1]=v end
    end
    if #out == 0 then out[1] = "unknown" end
    table.sort(out)
    return out
end

local function getMethods(name)
    local ok, raw = pcall(peripheral.getMethods, name)
    if not ok or type(raw) ~= "table" then return {}, {} end
    local out, set = {}, {}
    for _, m in ipairs(raw) do
        if type(m)=="string" and not set[m] then set[m]=true; out[#out+1]=m end
    end
    table.sort(out)
    return out, set
end

local sensorTypeWords = {
    "sensor","detector","scanner","reader","observer","analyzer","analyser",
    "environment","weather","biome","radiation","thermometer","barometer",
    "playerdetector","entitydetector","blockreader","geoscanner"
}
local observationWords = {
    "temperature","humidity","radiation","pressure","biome","dimension","weather",
    "raining","thunder","sunny","moon","solar","player","entity","blocklight",
    "skylight","daylight","scan","radius","range","slimechunk"
}
local infraWords = { "monitor","modem","speaker","printer","drive","computer","turtle" }
local nonSensorWords = { "bridge","storage","inventory","tank","flux","energy","induction","redstone","relay","router","network" }

local function joined(types) return table.concat(types or {}, " ") end
local function typeHas(types, words)
    local text = joined(types)
    for _, w in ipairs(words) do if has(text, w) then return true end end
    return false
end

local function observationScore(types, methodList)
    local score = 0
    if typeHas(types, sensorTypeWords) then score = score + 8 end
    for _, method in ipairs(methodList or {}) do
        local nm = norm(method)
        if nm:sub(1,3)=="get" or nm:sub(1,2)=="is" or nm:find("scan",1,true) then
            for _, w in ipairs(observationWords) do
                if nm:find(norm(w),1,true) then score=score+1; break end
            end
        end
    end
    return score
end

local function classify(types, methodList, methods)
    local cats, set = {}, {}
    local function add(v) if not set[v] then set[v]=true; cats[#cats+1]=v end end
    local score = observationScore(types, methodList)
    local infra = typeHas(types, infraWords)
    local knownNonSensor = typeHas(types, nonSensorWords)

    if infra then add("infrastructure") end
    if score > 0 then add("sensor") end
    if typeHas(types,{"flux","energy","induction"}) or methods.getEnergy or methods.getStoredEnergy or methods.getTransferRate then add("power") end
    if typeHas(types,{"redstone","door","gate","piston","relay"}) or methods.setOutput or methods.setAnalogOutput or methods.setAnalogueOutput or methods.open or methods.close or methods.setOpen or methods.setEnabled or methods.setActive then add("control") end
    if typeHas(types,{"inventory","storage","tank"}) or methods.list or methods.tanks or methods.size then add("storage") end
    if typeHas(types,{"bridge","network","router","modem"}) then add("network") end

    -- Advanced Peripherals and other mods often ship new detector names before KIMI knows
    -- them. A non-infrastructure, non-storage/control peripheral with meaningful methods
    -- is still surfaced as a data peripheral instead of disappearing from diagnostics.
    local data = not infra and (#methodList > 0)
    if data then add("data") end
    if data and score==0 and not knownNonSensor and not set.power and not set.storage and not set.control and not set.network then
        add("sensor_candidate")
    end
    if #cats==0 then add("peripheral") end
    return cats, score, infra, data
end

local function snapshot(obj, methods)
    local m = {}
    local function add(key, method, fallback, ...)
        if methods[method] then local v,ok=safeCall(obj,method,fallback,...); if ok then m[key]=v end end
    end
    add("reportedName","getName",nil)
    add("weatherRaining","isRaining",false); add("weatherThunder","isThunder",false); add("weatherThunder","isThundering",false); add("weatherSunny","isSunny",false)
    add("biome","getBiome",nil); add("dimension","getDimension",nil); add("dimension","getDimensionName",nil)
    add("blockLight","getBlockLightLevel",nil); add("skyLight","getSkyLightLevel",nil); add("dayLight","getDayLightLevel",nil)
    add("temperature","getTemperature",nil); add("humidity","getHumidity",nil); add("pressure","getPressure",nil)
    add("radiation","getRadiation",nil); add("radiationRaw","getRadiationRaw",nil); add("solarRadiation","getSolarRadiation",nil)
    add("moonPhase","getMoonPhase",nil); add("moonId","getMoonId",nil); add("worldTime","getTime",nil); add("slimeChunk","isSlimeChunk",nil)
    add("block","getBlockName",nil); add("maxScanRadius","getMaxScanRadius",nil)
    add("energy","getEnergy",nil); add("storedEnergy","getStoredEnergy",nil); add("energyCapacity","getEnergyCapacity",nil); add("maxEnergy","getMaxEnergy",nil); add("transferRate","getTransferRate",nil)
    add("networkName","getNetworkName",nil); add("playerCount","getPlayerCount",nil); add("entityCount","getEntityCount",nil); add("range","getRange",nil)
    if methods.getOnlinePlayers then local p,ok=safeCall(obj,"getOnlinePlayers",nil); if ok and type(p)=="table" then m.onlinePlayers=countTable(p); m.players=p end end
    if type(m.radiation)=="table" then m.radiationUnit=m.radiation.unit; m.radiationText=m.radiation.radiation end
    return m
end

local function summary(m)
    if m.biome or m.dimension then return tostring(m.biome or "?").." / "..tostring(m.dimension or "?") end
    if m.onlinePlayers~=nil then return tostring(m.onlinePlayers).." player(s) online" end
    if m.playerCount~=nil then return tostring(m.playerCount).." player(s)" end
    if m.entityCount~=nil then return tostring(m.entityCount).." entities" end
    if m.temperature~=nil then return "Temperature "..tostring(m.temperature) end
    if m.radiationRaw~=nil then return "Radiation "..tostring(m.radiationRaw) end
    if m.radiationText~=nil then return "Radiation "..tostring(m.radiationText) end
    if m.humidity~=nil then return "Humidity "..tostring(m.humidity) end
    if m.pressure~=nil then return "Pressure "..tostring(m.pressure) end
    if m.weatherThunder then return "Thunder" end
    if m.weatherRaining then return "Raining" end
    if m.weatherSunny then return "Sunny" end
    if m.maxScanRadius~=nil then return "Scanner / max "..tostring(m.maxScanRadius) end
    return "Online"
end

local function category(entry, wanted)
    for _, c in ipairs(entry.categories or {}) do if c==wanted then return true end end
    return false
end

function M.read()
    local devices, sensors, dataDevices, counts = {}, {}, {}, {}
    local names = peripheral.getNames(); table.sort(names)
    for _, name in ipairs(names) do
        local types=getTypes(name); local methodList, methods=getMethods(name); local obj=peripheral.wrap(name)
        local cats, score, infra, data = classify(types,methodList,methods); local metrics=snapshot(obj,methods)
        local entry={
            name=name, type=types[1] or "unknown", types=types, categories=cats,
            methods=methodList, methodCount=#methodList, metrics=metrics,
            reportedName=metrics.reportedName, summary=summary(metrics), online=obj~=nil,
            sensorScore=score, infrastructure=infra, dataPeripheral=data
        }
        devices[#devices+1]=entry
        for _, c in ipairs(cats) do counts[c]=(counts[c] or 0)+1 end
        if category(entry,"sensor") or category(entry,"sensor_candidate") then sensors[#sensors+1]=entry end
        if data then dataDevices[#dataDevices+1]=entry end
    end

    local visible, dataTypes = {}, {}
    for _, d in ipairs(devices) do visible[#visible+1]=(d.name or "?").."="..(d.type or "unknown") end
    for _, d in ipairs(dataDevices) do dataTypes[#dataTypes+1]=d.type or "unknown" end
    local onlyInfrastructure = #devices>0 and #dataDevices==0
    local hint
    if #sensors>0 then hint="sensor link healthy"
    elseif onlyInfrastructure then hint="only monitor/modem infrastructure is visible; connect detector adjacent to this computer or through an attached wired modem"
    elseif #dataDevices>0 then hint="data peripherals are visible but none expose known sensor semantics"
    else hint="no peripherals are visible to this computer" end

    return {
        count=#devices, sensorCount=#sensors, dataCount=#dataDevices,
        devices=devices, sensors=sensors, dataDevices=dataDevices, categories=counts,
        diagnostics={onlyInfrastructure=onlyInfrastructure,visible=visible,dataTypes=dataTypes,hint=hint},
        _status="online", _updated=os.epoch("utc")
    }
end

return M
