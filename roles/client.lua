local M = {}
local network = require("core.network")

local function loadProfile(name)
    local ok, profile = pcall(require, "clients." .. tostring(name or "terminal"))
    if ok and type(profile) == "table" then return profile end
    return require("clients.terminal")
end

function M.run(cfg)
    network.openAll()
    local profile = loadProfile(cfg.profile)
    local serverId, state, lastSeen = nil, nil, 0
    if profile.init then profile.init(cfg) end

    local timer = os.startTimer(0.1)
    while true do
        local e = { os.pullEvent() }
        if e[1] == "timer" and e[2] == timer then
            if not serverId then serverId = network.findServer(cfg) end
            if serverId then network.send(serverId, cfg, "state.get", { clientId = os.getComputerID(), profile = cfg.profile }) end
            if profile.render then profile.render(state, { connected = serverId ~= nil, lastSeen = lastSeen, serverId = serverId }) end
            timer = os.startTimer(1)

        elseif e[1] == "rednet_message" then
            local sender, msg, protocol = e[2], e[3], e[4]
            if protocol == cfg.network.protocol and sender == serverId and type(msg) == "table" and msg.kind == "state" then
                state = msg.payload
                lastSeen = os.epoch("utc")
                if profile.onState then profile.onState(state) end
                if profile.render then profile.render(state, { connected = true, lastSeen = lastSeen, serverId = serverId }) end
            end

        elseif e[1] == "peripheral" or e[1] == "peripheral_detach" then
            network.openAll()
            serverId = network.findServer(cfg)
            if profile.onPeripheralChange then profile.onPeripheralChange() end

        else
            if profile.handleEvent then profile.handleEvent(e, state, function(module, action, args)
                if serverId then network.send(serverId, cfg, "command", { module = module, action = action, args = args }) end
            end) end
        end
    end
end

return M
