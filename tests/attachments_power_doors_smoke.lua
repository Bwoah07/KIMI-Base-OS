local realPrint = print
local logs = {}

colors = {
    black=1, white=2, red=3, lime=4, yellow=5, lightGray=6,
    gray=7, orange=8, blue=9, green=10
}

local function newSurface(width, height)
    local rows = {}
    local cursorX, cursorY = 1, 1
    local surface = {}
    surface.setTextScale = function() end
    surface.setBackgroundColor = function() end
    surface.setTextColor = function() end
    surface.clear = function() rows = {}; cursorX, cursorY = 1, 1 end
    surface.setCursorPos = function(x, y) cursorX, cursorY = x, y end
    surface.write = function(value)
        local text = tostring(value):sub(1, math.max(0, width-cursorX+1))
        if cursorY>=1 and cursorY<=height and cursorX<=width then
            local row = rows[cursorY] or string.rep(" ", width)
            rows[cursorY] = row:sub(1, cursorX-1) .. text .. row:sub(cursorX+#text)
        end
        cursorX = cursorX + #text
    end
    surface.getSize = function() return width, height end
    surface.output = function()
        local out = {}
        for y=1,height do out[y] = rows[y] or string.rep(" ", width) end
        return table.concat(out, "\n")
    end
    return surface
end

local computerOutputs = {}
redstone = {
    getOutput = function(side) return computerOutputs[side] == true end,
    setOutput = function(side, value) computerOutputs[side] = value == true end
}

local integratorOutputs = {}
local gateOpen = false
local devices = {
    flux_controller_1 = {
        type = "flux_controller",
        object = {
            getNetworkStats = function() return {
                name="KIMI POWER", input=1200000, inputExact="1200000",
                output=800000, outputExact="800000", net=400000, netExact="400000",
                stored=48000000000, storedExact="48000000000", capacity=64000000000,
                capacityExact="64000000000", plugs=3, points=4, storages=2,
                controllers=1, devices=10, averageTickMicroseconds=12.5
            } end,
            getDevices = function() return {
                { id="minecraft:overworld@1,2,3", name="Factory", type="point", status="online" }
            } end,
            getWarnings = function() return {
                { deviceId="minecraft:overworld@4,5,6", message="target chunk unloaded" }
            } end,
            getHealth = function() return { healthy=false, status="warning", devices=10 } end,
            getNetworkName = function() return "KIMI POWER" end,
            getStoredEnergy = function() return 48000000000 end,
            getEnergyCapacity = function() return 64000000000 end,
            getEnergyInput = function() return 1200000 end,
            getEnergyOutput = function() return 800000 end
        }
    },
    flux_controller_2 = {
        type = "flux_controller",
        object = {
            getNetworkStats = function() return {
                name="KIMI POWER", input=250000, output=100000, net=150000,
                stored=8000000000, capacity=32000000000, plugs=1, points=2,
                storages=1, controllers=1, devices=5, averageTickMicroseconds=4.5
            } end,
            getDevices = function() return {} end,
            getWarnings = function() return {} end,
            getHealth = function() return { healthy=true, status="online" } end
        }
    },
    induction_port_1 = {
        type = "mekanism:induction_port",
        object = {
            getEnergy = function() return 9000000 end,
            getMaxEnergy = function() return 12000000 end,
            getLastInput = function() return 40000 end,
            getLastOutput = function() return 10000 end,
            getTransferCap = function() return 500000 end,
            getEnergyFilledPercentage = function() return 0.75 end,
            getInstalledCells = function() return 8 end,
            getInstalledProviders = function() return 4 end,
            getMode = function() return "OUTPUT" end
        }
    },
    environment_detector_1 = {
        type = "environment_detector",
        object = {
            isRaining = function() return false end,
            isThunder = function() return false end,
            isSunny = function() return true end,
            getBiome = function() return "minecraft:plains" end,
            getDimension = function() return "minecraft:overworld" end,
            getBlockLightLevel = function() return 12 end,
            getSkyLightLevel = function() return 15 end
        }
    },
    player_detector_1 = {
        type = "player_detector",
        object = { getOnlinePlayers = function() return { "Stig", "Kimi" } end }
    },
    redstone_integrator_1 = {
        type = "redstone_integrator",
        object = {
            getOutput = function(side) return integratorOutputs[side] == true end,
            setOutput = function(side, value) integratorOutputs[side] = value == true end
        }
    },
    access_gate_1 = {
        type = "access_gate",
        object = {
            isOpen = function() return gateOpen end,
            open = function() gateOpen = true end,
            close = function() gateOpen = false end
        }
    }
}

local monitors = {}
local function useMonitors(count)
    for name in pairs(monitors) do devices[name] = nil end
    monitors = {}
    local specs = {}
    if type(count)=="table" then specs=count else
        for index=1,count do specs[index]={ name="monitor_"..index, width=80, height=30 } end
    end
    for index,spec in ipairs(specs) do
        local name = spec.name or ("monitor_" .. index)
        local surface = newSurface(spec.width or 80, spec.height or 30)
        monitors[name] = surface
        devices[name] = { type="monitor", object=surface }
    end
end

local function methodsOf(object)
    local out = {}
    for key, value in pairs(object or {}) do if type(value) == "function" then out[#out + 1] = key end end
    table.sort(out)
    return out
end

peripheral = {}
peripheral.getNames = function()
    local out = {}
    for name in pairs(devices) do out[#out + 1] = name end
    table.sort(out)
    return out
end
peripheral.getType = function(name) return devices[name] and devices[name].type end
peripheral.hasType = function(name, wanted) return devices[name] and devices[name].type == wanted or false end
peripheral.getMethods = function(name) return methodsOf(devices[name] and devices[name].object) end
peripheral.wrap = function(name) return devices[name] and devices[name].object end
peripheral.isPresent = function(name) return devices[name] ~= nil end
peripheral.getName = function(object)
    for name, device in pairs(devices) do if device.object == object then return name end end
end

term = newSurface(80, 30)
os = {
    getComputerID = function() return 84 end,
    getComputerLabel = function() return "KIMI TEST" end,
    epoch = function() return 2000000 end,
    time = function() return 12.5 end,
    day = function() return 12 end,
    clock = function() return 3600 end
}
sleep = function() end
print = function(...)
    local parts = {}
    for index=1,select("#", ...) do parts[index] = tostring(select(index, ...)) end
    logs[#logs + 1] = table.concat(parts, "\t")
end

local powerModule = assert(loadfile("modules/power.lua"))()
local power = powerModule.read()
assert(power.fluxCount == 2, "every attached Flux Controller must stay visible even when names match")
assert(power.matrixCount == 1, "Mekanism Matrix was hidden by Flux")
assert(power.networkName == "KIMI POWER", "Flux network stats were not selected")
local sawExactFlux = false
for _,network in ipairs(power.fluxNetworks) do
    if network.storedExact == "48000000000" and network.warningCount == 1 and network.deviceCount == 10 then sawExactFlux = true end
end
assert(sawExactFlux, "exact Flux FE value or device health was not retained")

local attachmentsModule = assert(loadfile("modules/attachments.lua"))()
local attachments = attachmentsModule.read()
assert(attachments.count == 7, "not every attachment was inventoried")
assert(attachments.sensorCount == 2, "sensor classification did not find every sensor")
local sawPlayers = false
for _, sensor in ipairs(attachments.sensors) do
    if sensor.type == "player_detector" then
        sawPlayers = sensor.metrics.onlinePlayers == 2 and sensor.methodCount == 1
    end
end
assert(sawPlayers, "player detector snapshot or method inventory missing")

local doorsModule = assert(loadfile("modules/doors.lua"))()
local doors = doorsModule.read()
assert(doors.controllerCount == 3 and doors.candidateCount == 13, "door setup candidates were not discovered")
assert(doors.channelCount == 0, "raw redstone outputs must not be guessed as configured doors")
doorsModule.handleCommand("toggle", { target="computer", side="right" })
assert(computerOutputs.right == true, "computer redstone door did not toggle")
doorsModule.handleCommand("open", { target="redstone_integrator_1", side="north" })
assert(integratorOutputs.north == true, "redstone integrator door did not open")
doorsModule.handleCommand("open", { target="access_gate_1" })
assert(gateOpen == true, "direct gate peripheral did not open")
doorsModule.handleCommand("close", { target="access_gate_1" })
assert(gateOpen == false, "direct gate peripheral did not close")

local registry = assert(loadfile("core/door_registry.lua"))()
local candidates = registry.candidates({ { sourceId="server", value=doors } })
local entries = {}
local added = assert(registry.add(entries, candidates, candidates[1].key))
local doorState = registry.snapshot(entries, candidates)
assert(doorState.doorCount == 1 and doorState.candidateCount == 13, "explicit door registry did not separate doors from candidates")
assert(doorState.doors[1].name == "DOOR 01" and doorState.doors[1].online, "configured door state missing")

for _,candidate in ipairs(doorState.candidates) do
    candidate.configured = candidate.key == added.key
end

local envelope = {
    version="5.0.0-alpha.31", schema=2, generated=1900000,
    state={
        environment={ weather="SUNNY", biome="minecraft:plains", moon="FULL" },
        system={ computerId=84, ingameDay=12, uptime=3600, peripherals={} },
        fleet={}, sources={}, update={ fleetCurrent=2, fleetOutdated=1, fleetOffline=0 }, power=power, attachments=attachments, doors=doorState
    }
}
local meta = { connected=true, serverId=84, startedAt=1000000, localVersion="5.0.0-alpha.31", machines={}, sources={}, update={ fleetCurrent=2, fleetOutdated=1, fleetOffline=0 } }

useMonitors({
    { name="monitor_left", width=40, height=30 },
    { name="monitor_middle", width=90, height=30 },
    { name="monitor_right", width=32, height=30 }
})
local admin = assert(loadfile("clients/admin.lua"))()
admin.init()
admin.render(envelope, meta)
assert(monitors.monitor_middle.output():find("ENERGY COMMAND", 1, true), "largest monitor was not selected for energy")
assert(monitors.monitor_middle.output():find("75.0%%"), "admin Matrix battery percentage missing")
assert(monitors.monitor_middle.output():find("FLUX 1/2", 1, true) and monitors.monitor_middle.output():find("FLUX 2/2", 1, true), "both Flux networks were not rendered")
assert(monitors.monitor_left.output():find("KIMI COMMAND", 1, true), "second-largest monitor did not get clock/weather overview")
assert(monitors.monitor_left.output():find("WEATHER", 1, true) and monitors.monitor_left.output():find("MINECRAFT DAY", 1, true), "weather/day/clock overview missing")
assert(monitors.monitor_right.output():find("ALL SENSORS", 1, true), "third monitor did not show every sensor")

local actionCall
admin.handleEvent({ "monitor_touch", "monitor_middle", 50, 29 }, envelope, function(...) actionCall={...} end)
assert(monitors.monitor_middle.output():find("DOOR MANAGER", 1, true), "DOORS navigation was not immediately responsive")
admin.handleEvent({ "monitor_touch", "monitor_middle", 5, 11 }, envelope, function(...) actionCall={...} end)
assert(actionCall and actionCall[1] == "doors" and actionCall[2] == "toggle", "door touchscreen did not issue a toggle command")
admin.handleEvent({ "monitor_touch", "monitor_middle", 5, 6 }, envelope, function(...) actionCall={...} end)
assert(monitors.monitor_middle.output():find("ADD A DOOR", 1, true), "ADD DOOR screen was not immediately responsive")
admin.handleEvent({ "monitor_touch", "monitor_middle", 5, 5 }, envelope, function(...) actionCall={...} end)
assert(actionCall and actionCall[1] == "doors" and actionCall[2] == "register", "door setup did not issue an explicit register command")
admin.handleEvent({ "monitor_touch", "monitor_middle", 80, 29 }, envelope, function(...) actionCall={...} end)
assert(actionCall and actionCall[1] == "server" and actionCall[2] == "sync_fleet", "SYNC FLEET did not issue a server sync command")

useMonitors({ { name="monitor_tiny", width=36, height=20 } })
local adminSingle = assert(loadfile("clients/admin.lua"))()
adminSingle.init(); adminSingle.render(envelope, meta)
assert(monitors.monitor_tiny.output():find("ENERGY COMMAND", 1, true), "single narrow monitor did not adapt to energy view")
adminSingle.handleEvent({ "monitor_touch", "monitor_tiny", 5, 18 }, envelope, function(...) actionCall={...} end)
assert(monitors.monitor_tiny.output():find("DOOR MANAGER", 1, true), "narrow monitor navigation was not responsive")

useMonitors({
    { name="wall_left", width=40, height=30 },
    { name="wall_middle", width=90, height=30 },
    { name="wall_right", width=32, height=30 }
})
local wallAdaptive = assert(loadfile("clients/wall.lua"))()
wallAdaptive.init(); wallAdaptive.render(envelope, meta)
assert(monitors.wall_middle.output():find("ENERGY COMMAND", 1, true), "wall client did not assign its largest monitor to energy")
assert(monitors.wall_left.output():find("KIMI BASE", 1, true), "wall client did not assign overview by monitor area")
assert(monitors.wall_right.output():find("ALL SENSORS", 1, true), "wall client did not assign sensors by monitor area")

useMonitors(7)
local wall = assert(loadfile("clients/wall.lua"))()
wall.init(); wall.render(envelope, meta)
assert(monitors.monitor_1.output():find("ENERGY COMMAND", 1, true), "wall largest/default monitor did not prioritize energy")
assert(monitors.monitor_1.output():find("75.00%%"), "wall Matrix battery percentage missing")
assert(monitors.monitor_1.output():find("FLUX", 1, true), "wall energy panel did not list Flux")
assert(monitors.monitor_2.output():find("KIMI BASE", 1, true), "wall overview missing")
assert(monitors.monitor_3.output():find("ALL SENSORS", 1, true), "wall sensors missing")
assert(monitors.monitor_5.output():find("FLUX + MATRIX", 1, true), "wall did not render combined power")
assert(monitors.monitor_6.output():find("ALL ATTACHMENTS", 1, true), "wall did not render attachments")
assert(monitors.monitor_7.output():find("CONFIGURED DOORS", 1, true), "wall did not render configured door state")

logs = {}
local terminal = assert(loadfile("clients/terminal.lua"))()
terminal.init(); terminal.render(envelope, meta)
local terminalOutput = table.concat(logs, "\n")
assert(terminalOutput:find("Attach:", 1, true), "terminal attachment summary missing")
assert(terminalOutput:find("Sources: Flux 2 / Matrix 1", 1, true), "terminal combined power summary missing")
assert(terminalOutput:find("Flux 2:", 1, true), "terminal hid the second Flux network")

realPrint("Attachments, power, sensors, and doors smoke test passed")
