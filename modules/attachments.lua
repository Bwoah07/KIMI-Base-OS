local M = { id = "attachments" }

local function safeCall(obj,method,fallback,...)
    if not obj or type(obj[method])~="function" then return fallback,false end
    local ok,value=pcall(obj[method],...)
    if not ok or value==nil then return fallback,false end
    return value,true
end
local function normalized(text) return tostring(text or ""):lower():gsub("[^a-z0-9]","") end
local function contains(text,needle) return normalized(text):find(normalized(needle),1,true)~=nil end

local function getTypes(name)
    local result={pcall(peripheral.getType,name)}
    if not result[1] then return {"unknown"} end
    table.remove(result,1)
    local out,seen={},{}
    for _,value in ipairs(result) do if type(value)=="string" and not seen[value] then seen[value]=true; out[#out+1]=value end end
    if #out==0 then out[1]="unknown" end
    table.sort(out); return out
end
local function getMethods(name)
    local ok,value=pcall(peripheral.getMethods,name)
    if not ok or type(value)~="table" then return {},{} end
    local out,set={},{}
    for _,method in ipairs(value) do if type(method)=="string" and not set[method] then set[method]=true; out[#out+1]=method end end
    table.sort(out); return out,set
end

local sensorTypeWords={"sensor","detector","scanner","reader","analyzer","analyser","observer","thermometer","barometer","seismometer","radiation","weather","environment","biome","playerdetector","entitydetector","blockreader","geoscanner"}
local observationWords={"temperature","humidity","radiation","pressure","biome","dimension","weather","raining","thunder","sunny","moon","solar","player","entity","blocklight","skylight","daylight","scan","radius","range","slimechunk"}

local function sensorScore(types,methodList)
    local score=0; local joined=table.concat(types or {}," ")
    for _,word in ipairs(sensorTypeWords) do if contains(joined,word) then score=score+4; break end end
    for _,method in ipairs(methodList or {}) do
        local nm=normalized(method)
        if nm:sub(1,3)=="get" or nm:sub(1,2)=="is" or nm:find("scan",1,true) then
            for _,word in ipairs(observationWords) do
                if nm:find(normalized(word),1,true) then score=score+1; break end
            end
        end
    end
    return score
end

local function primaryType(types,score)
    if score>0 then
        for _,value in ipairs(types or {}) do
            for _,word in ipairs(sensorTypeWords) do if contains(value,word) then return value end end
        end
    end
    return types and types[1] or "unknown"
end

local function classify(types,methodList,methods)
    local joined=table.concat(types or {}," "):lower(); local categories,set={},{}
    local function add(v) if not set[v] then set[v]=true; categories[#categories+1]=v end end
    local score=sensorScore(types,methodList)
    if score>0 then add("sensor") end
    if contains(joined,"flux") or contains(joined,"energy") or contains(joined,"induction") or methods.getEnergy or methods.getStoredEnergy or methods.getTransferRate then add("power") end
    if contains(joined,"redstone") or contains(joined,"door") or contains(joined,"gate") or contains(joined,"piston") or methods.setOutput or methods.setAnalogOutput or methods.open or methods.close or methods.setOpen then add("control") end
    if contains(joined,"inventory") or contains(joined,"storage") or contains(joined,"tank") or methods.list or methods.tanks or methods.size then add("storage") end
    if contains(joined,"monitor") or contains(joined,"printer") or contains(joined,"speaker") then add("display") end
    if contains(joined,"modem") or contains(joined,"bridge") or contains(joined,"network") then add("network") end
    if contains(joined,"computer") or contains(joined,"turtle") or contains(joined,"drive") then add("computer") end
    if #categories==0 then add("peripheral") end
    return categories,score
end

local function countTable(value) if type(value)~="table" then return nil end; local n=0; for _ in pairs(value) do n=n+1 end; return n end
local function snapshot(obj,methods)
    local metrics={}
    local function add(key,method,fallback,...)
        if methods[method] then local value,ok=safeCall(obj,method,fallback,...); if ok then metrics[key]=value end end
    end
    add("weatherRaining","isRaining",false); add("weatherThunder","isThunder",false); add("weatherThunder","isThundering",false); add("weatherSunny","isSunny",false)
    add("biome","getBiome",nil); add("dimension","getDimension",nil); add("dimension","getDimensionName",nil)
    add("blockLight","getBlockLightLevel",nil); add("skyLight","getSkyLightLevel",nil); add("dayLight","getDayLightLevel",nil)
    add("temperature","getTemperature",nil); add("humidity","getHumidity",nil); add("pressure","getPressure",nil)
    add("radiation","getRadiation",nil); add("radiationRaw","getRadiationRaw",nil); add("solarRadiation","getSolarRadiation",nil)
    add("moonPhase","getMoonPhase",nil); add("moonId","getMoonId",nil); add("worldTime","getTime",nil); add("slimeChunk","isSlimeChunk",nil)
    add("block","getBlockName",nil); add("maxScanRadius","getMaxScanRadius",nil)
    add("energy","getEnergy",nil); add("storedEnergy","getStoredEnergy",nil); add("energyCapacity","getEnergyCapacity",nil); add("maxEnergy","getMaxEnergy",nil); add("transferRate","getTransferRate",nil)
    add("networkName","getNetworkName",nil); add("colonyName","getColonyName",nil); add("colonyId","getColonyID",nil); add("owner","getOwner",nil); add("inventorySize","size",nil)
    add("playerCount","getPlayerCount",nil); add("entityCount","getEntityCount",nil); add("range","getRange",nil)
    if methods.getOnlinePlayers then local players,ok=safeCall(obj,"getOnlinePlayers",nil); if ok and type(players)=="table" then metrics.onlinePlayers=countTable(players); metrics.players=players end end
    if type(metrics.radiation)=="table" then metrics.radiationUnit=metrics.radiation.unit; metrics.radiationText=metrics.radiation.radiation end
    return metrics
end

local function summary(m)
    if m.biome or m.dimension then return tostring(m.biome or "?").." / "..tostring(m.dimension or "?") end
    if m.onlinePlayers~=nil then return tostring(m.onlinePlayers).." player(s) online" end
    if m.playerCount~=nil then return tostring(m.playerCount).." player(s)" end
    if m.entityCount~=nil then return tostring(m.entityCount).." entities" end
    if m.temperature~=nil then return "Temperature "..tostring(m.temperature) end
    if m.radiationRaw~=nil then return "Radiation "..tostring(m.radiationRaw) end
    if m.radiationText~=nil then return "Radiation "..tostring(m.radiationText) end
    if m.solarRadiation~=nil then return "Solar radiation "..tostring(m.solarRadiation) end
    if m.humidity~=nil then return "Humidity "..tostring(m.humidity) end
    if m.pressure~=nil then return "Pressure "..tostring(m.pressure) end
    if m.weatherThunder then return "Thunder" end
    if m.weatherRaining then return "Raining" end
    if m.weatherSunny then return "Sunny" end
    if m.maxScanRadius~=nil then return "Scanner online / max "..tostring(m.maxScanRadius) end
    if m.block then return "Block "..tostring(m.block) end
    if m.networkName then return "Network "..tostring(m.networkName) end
    if m.transferRate~=nil then return tostring(m.transferRate).." FE/t" end
    if m.storedEnergy~=nil or m.energy~=nil then return tostring(m.storedEnergy or m.energy).." FE" end
    if m.colonyName then return "Colony "..tostring(m.colonyName) end
    if m.inventorySize~=nil then return tostring(m.inventorySize).." slots" end
    return "Online"
end

function M.read()
    local devices,sensors,counts,typesSeen={},{},{},{}
    local names=peripheral.getNames(); table.sort(names)
    for _,name in ipairs(names) do
        local types=getTypes(name); local methodList,methodLookup=getMethods(name); local obj=peripheral.wrap(name)
        local categories,score=classify(types,methodList,methodLookup); local metrics=snapshot(obj,methodLookup)
        local entry={name=name,type=primaryType(types,score),types=types,categories=categories,methods=methodList,methodCount=#methodList,metrics=metrics,summary=summary(metrics),online=obj~=nil,sensorScore=score}
        devices[#devices+1]=entry
        for _,t in ipairs(types) do typesSeen[t]=true end
        for _,category in ipairs(categories) do counts[category]=(counts[category] or 0)+1; if category=="sensor" then sensors[#sensors+1]=entry end end
    end
    local typeList={}; for t in pairs(typesSeen) do typeList[#typeList+1]=t end; table.sort(typeList)
    return {count=#devices,sensorCount=#sensors,devices=devices,sensors=sensors,categories=counts,typesSeen=typeList,_status="online",_updated=os.epoch("utc")}
end

return M
