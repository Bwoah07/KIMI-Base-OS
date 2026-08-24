local realPrint = print

colors = {
    white = 1, orange = 2, magenta = 4, lightBlue = 8, yellow = 16, lime = 32,
    pink = 64, gray = 128, lightGray = 256, cyan = 512, purple = 1024,
    blue = 2048, brown = 4096, green = 8192, red = 16384, black = 32768
}

local function surface(width, height)
    local rows = {}
    local x, y = 1, 1
    local s = {}
    s.setTextScale = function() end
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

local adaptive = assert(loadfile("clients/adaptive.lua"))()
local wall = adaptive.create({ mode = "wall" })
wall.init({ name = "Front Gate" })

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

local localPower = {
    onlineSources = 1,
    matrixCount = 1,
    fluxCount = 0,
    stored = 750,
    capacity = 1000,
    input = 50,
    output = 20,
    filledPercentage = 0.75,
    matrices = {},
    fluxNetworks = {}
}

local envelope = {
    version = "5.0.0-alpha.32",
    state = {
        environment = { _status = "online", weather = "SUNNY", biome = "minecraft:plains", moon = "FULL MOON" },
        doors = { doors = { localDoor }, candidates = {}, candidateCount = 0 },
        attachments = { sensors = { localSensor }, sensorCount = 1, devices = { localSensor }, count = 1 },
        power = localPower,
        fleet = { [42] = { name = "Front Gate", role = "client", version = "5.0.0-alpha.32", online = true } },
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
assert(monitors.big.output():find("FRONT GATE", 1, true), "friendly computer label was not used for generic door name")
assert(monitors.medium.output():find("LOCAL POWER", 1, true), "second screen did not auto-select local power")
assert(monitors.small.output():find("LOCAL SENSORS", 1, true), "third screen did not auto-select local sensors")
assert(monitors.small.output():find("ENVIRONMENT_DETECTOR_1", 1, true), "local sensor did not render")

local called
wall.handleEvent({ "monitor_touch", "big", 5, 8 }, envelope, function(module, action, args)
    called = { module = module, action = action, args = args }
end)
assert(called, "door touch produced no action")
assert(called.module == "__local_doors" and called.action == "toggle", "remote local door did not use immediate local command path")
assert(called.args and tostring(called.args._source) == "42" and called.args.side == "right", "local door target data was lost")

realPrint("adaptive display smoke test OK")
