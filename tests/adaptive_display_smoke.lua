local realPrint = print

colors = {
    white = 1, orange = 2, magenta = 4, lightBlue = 8, yellow = 16, lime = 32,
    pink = 64, gray = 128, lightGray = 256, cyan = 512, purple = 1024,
    blue = 2048, brown = 4096, green = 8192, red = 16384, black = 32768
}

local function surface(width, height)
    local rows = {}
    local x, y = 1, 1
    local s = { lastScale = nil }
    s.setTextScale = function(value) s.lastScale = value end
    s.setBackgroundColor = function() end
    s.setTextColor = function() end
    s.clear = function() rows = {}; x, y = 1, 1 end
    s.setCursorPos = function(nx, ny) x, y = nx, ny end
    s.getSize = function() return width, height end
    s.write = function(value)
        value = tostring(value or "")
        if y < 1 or y > height or x > width then return end
        value = value:sub(1, math.max(0, width - x + 1))
        local row = rows[y] or string.rep(" ", width)
        rows[y] = row:sub(1, x - 1) .. value .. row:sub(x + #value)
        x = x + #value
    end
    s.output = function()
        local out = {}
        for row = 1, height do out[row] = rows[row] or string.rep(" ", width) end
        return table.concat(out, "\n")
    end
    return s
end

local devices = {}
local monitors = {
    big = surface(90, 30),
    medium = surface(48, 22),
    small = surface(32, 18)
}
for name, mon in pairs(monitors) do devices[name] = { type = "monitor", object = mon } end

peripheral = {}
peripheral.getNames = function()
    local out = {}
    for name in pairs(devices) do out[#out + 1] = name end
    table.sort(out)
    return out
end
peripheral.hasType = function(name, wanted) return devices[name] and devices[name].type == wanted or false end
peripheral.wrap = function(name) return devices[name] and devices[name].object end

term = { clear = function() end, setCursorPos = function() end }

local epoch = 1000000
os = {
    getComputerID = function() return 42 end,
    getComputerLabel = function() return "Front Gate" end,
    epoch = function() epoch = epoch + 1; return epoch end,
    time = function() return 12.5 end,
    day = function() return 8 end
}

local adaptive = assert(loadfile("clients/adaptive_v2.lua"))()
local wall = adaptive.create({ mode = "wall" })
wall.init({ name = "KIMI-42" })

local localDoor = {
    id = 1,
    name = "DOOR 01",
    source = "42",
    _source = "42",
    target = "computer",
    side = "right",
    online = true,
    open = false
}

local localSensor = {
    name = "environment_detector_1",
    type = "environment_detector",
    summary = "Sunny",
    metrics = { temperature = 21.5 },
    _source = "42"
}

-- Deliberately make the aggregate/root power values useless. The UI must pick
-- the healthy real source instead of rendering a giant 0/0 dashboard.
local goodMatrix = {
    sourceType = "mekanism_induction_port",
    stored = 750,
    capacity = 1000,
    input = 50,
    output = 20,
    filledPercentage = 0.75
}
local localPower = {
    onlineSources = 1,
    matrixCount = 1,
    fluxCount = 0,
    stored = 0,
    capacity = 0,
    input = 0,
    output = 0,
    matrices = { goodMatrix },
    fluxNetworks = {},
    energyDetectors = {}
}

local envelope = {
    version = "5.0.0-alpha.33",
    state = {
        environment = { _status = "online", weather = "SUNNY", biome = "minecraft:plains", moon = "FULL MOON" },
        doors = { doors = { localDoor }, candidates = {}, candidateCount = 0 },
        attachments = { sensors = { localSensor }, sensorCount = 1, devices = { localSensor }, count = 1 },
        power = localPower,
        fleet = { [42] = { name = "Front Gate", role = "client", version = "5.0.0-alpha.33", online = true } },
        sources = { ["42"] = { name = "Front Gate", role = "client", online = true } },
        update = { syncResult = "1 current" }
    }
}

local meta = {
    connected = true,
    serverId = 1,
    localServer = false,
    localState = {
        doors = { candidates = {} },
        attachments = { sensors = { localSensor }, sensorCount = 1 },
        power = localPower
    }
}

wall.render(envelope, meta)
assert(monitors.big.output():find("LOCAL DOORS", 1, true), "largest screen did not auto-select local doors")
assert(monitors.big.output():find("FRONT GATE", 1, true), "friendly ComputerCraft label was not used")
assert(monitors.medium.output():find("LOCAL POWER", 1, true), "second screen did not auto-select local power")
assert(monitors.medium.output():find("75.0%%"), "power screen chose the useless 0/0 aggregate instead of a real source")
assert(monitors.small.output():find("LOCAL SENSORS", 1, true), "third screen did not auto-select local sensors")
assert(monitors.small.output():find("ENVIRONMENT_DETECTOR_1", 1, true), "local sensor did not render")
assert(monitors.big.lastScale == 1.0 and monitors.medium.lastScale == 1.0 and monitors.small.lastScale == 1.0, "normal monitors should prefer readable text scale 1.0")

local called
wall.handleEvent({ "monitor_touch", "big", 5, 8 }, envelope, function(module, action, args)
    called = { module = module, action = action, args = args }
end)
assert(called, "door touch produced no action")
assert(called.module == "__local_doors" and called.action == "toggle", "remote local door did not use immediate local command path")
assert(called.args and tostring(called.args._source) == "42" and called.args.side == "right", "local door target data was lost")

-- A status-only wall client with generic sensor telemetry but no dedicated
-- environment module must not contradict itself with 'NO WEATHER SENSOR'.
local onlyStatus = surface(34, 18)
devices.big, devices.medium, devices.small = nil, nil, nil
devices.status = { type = "monitor", object = onlyStatus }
local statusWall = adaptive.create({ mode = "wall" })
statusWall.init({ name = "Hallway" })
local statusEnvelope = {
    version = "5.0.0-alpha.33",
    state = {
        attachments = { sensors = { { name="player_detector", type="player_detector", metrics={ onlinePlayers=2 }, _source="server" } } },
        doors = { doors = {}, candidates = {} },
        power = { onlineSources = 0 },
        fleet = { [1] = { name="Main", online=true } }
    }
}
statusWall.render(statusEnvelope, { connected=true, localState={ attachments={ sensors={} }, power={ onlineSources=0 } } })
assert(onlyStatus.output():find("1 SENSOR ONLINE", 1, true), "status screen did not surface generic sensor telemetry")
assert(not onlyStatus.output():find("NO WEATHER SENSOR", 1, true), "status screen contradicted available sensors")

realPrint("adaptive display v2 smoke test OK")