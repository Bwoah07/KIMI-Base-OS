local M = {}

local ROOT = ".kimi"
local PATH = ROOT .. "/doors"

local function copy(value)
    local out = {}
    for key, item in pairs(value or {}) do out[key] = item end
    return out
end

local function readFile(path)
    if not fs.exists(path) or fs.isDir(path) then return nil end
    local file = fs.open(path, "r")
    if not file then return nil end
    local body = file.readAll(); file.close(); return body
end

local function localKey(target, side)
    return tostring(target or "") .. "|" .. tostring(side or "")
end

function M.key(source, target, side)
    return tostring(source or "server") .. "|" .. tostring(target or "") .. "|" .. tostring(side or "")
end

function M.load()
    local body = readFile(PATH)
    local value = body and textutils.unserialize(body) or nil
    if type(value) ~= "table" then return {} end
    local out = {}
    for _, entry in ipairs(value) do
        if type(entry) == "table" and entry.target then out[#out + 1] = entry end
    end
    return out
end

function M.save(entries)
    if not fs.exists(ROOT) then fs.makeDir(ROOT) end
    local file = assert(fs.open(PATH, "w"))
    file.write(textutils.serialize(entries or {})); file.close()
end

function M.candidates(values)
    local out = {}
    for _, source in ipairs(values or {}) do
        local sourceId = tostring(source.sourceId or "server")
        local reported = source.value or {}
        local logicalByKey = {}
        for _, door in ipairs(reported.localDoors or {}) do
            if type(door) == "table" and door.target then
                logicalByKey[localKey(door.target, door.side)] = door
            end
        end

        if type(reported.candidates) == "table" then
            for _, candidate in ipairs(reported.candidates) do
                local item = copy(candidate)
                local logical = logicalByKey[localKey(item.target, item.side)]
                if logical then
                    -- candidates carry raw actuator signal, while localDoors carries
                    -- the configured LOGICAL state (including inverted outputs and
                    -- feedback inputs). Remote UIs must use the logical state or they
                    -- drift back to CLOSED after their optimistic shadow expires.
                    item.open = logical.open == true
                    item.signal = logical.signal == true
                    item.mode = logical.mode
                    item.stateSource = logical.stateSource
                    item.localConfigured = true
                    item.localName = logical.name or item.localName
                end
                item._source = sourceId
                item.key = M.key(sourceId, item.target, item.side)
                out[#out + 1] = item
            end
        else
            for _, controller in ipairs(reported.controllers or {}) do
                for _, channel in ipairs(controller.channels or {}) do
                    local item = {
                        target = controller.target,
                        side = channel.side,
                        label = channel.label or channel.side,
                        controller = controller.name,
                        type = controller.type,
                        kind = controller.kind,
                        open = channel.open == true,
                        readable = channel.readable == true,
                        _source = sourceId
                    }
                    local logical = logicalByKey[localKey(item.target, item.side)]
                    if logical then
                        item.open = logical.open == true
                        item.signal = logical.signal == true
                        item.mode = logical.mode
                        item.stateSource = logical.stateSource
                        item.localConfigured = true
                        item.localName = logical.name
                    end
                    item.key = M.key(sourceId, item.target, item.side)
                    out[#out + 1] = item
                end
            end
        end
    end
    table.sort(out, function(a, b) return tostring(a.key) < tostring(b.key) end)
    return out
end

function M.snapshot(entries, candidates)
    local byKey = {}
    for _, candidate in ipairs(candidates or {}) do byKey[candidate.key] = candidate end

    local doors, configured = {}, {}
    for _, entry in ipairs(entries or {}) do
        local key = entry.key or M.key(entry.source, entry.target, entry.side)
        local live = byKey[key]
        local item = copy(entry)
        item.key = key
        item._source = tostring(entry.source or "server")
        item.online = live ~= nil
        item.open = live and live.open == true or false
        item.readable = live and live.readable == true or false
        item.controller = live and live.controller or entry.controller
        item.type = live and live.type or entry.type
        item.mode = live and live.mode or entry.mode
        item.stateSource = live and live.stateSource or entry.stateSource
        doors[#doors + 1] = item
        configured[key] = true
    end

    -- Room panels can safely configure their own physically attached output.
    -- Those local registrations are reported as telemetry and automatically
    -- become fleet-visible doors without forcing the user through the central
    -- raw-output wizard again.
    for _, candidate in ipairs(candidates or {}) do
        if candidate.localConfigured == true and not configured[candidate.key] then
            local item = copy(candidate)
            item.id = "local:" .. tostring(candidate.key)
            item.name = candidate.localName or ((tostring(candidate.label or candidate.side or "LOCAL")):upper() .. " DOOR")
            item.source = tostring(candidate._source or "server")
            item._source = item.source
            item.online = true
            item.open = candidate.open == true
            item.readable = candidate.readable == true
            item.origin = "room"
            doors[#doors + 1] = item
            configured[candidate.key] = true
        end
    end

    local available = {}
    for _, candidate in ipairs(candidates or {}) do
        local item = copy(candidate)
        item.configured = configured[item.key] == true
        available[#available + 1] = item
    end

    table.sort(doors, function(a, b)
        local an, bn = tonumber(a.id), tonumber(b.id)
        if an and bn then return an < bn end
        if an then return true end
        if bn then return false end
        return tostring(a.key or a.id) < tostring(b.key or b.id)
    end)

    return {
        doors = doors,
        doorCount = #doors,
        candidates = available,
        candidateCount = #available,
        _status = "online",
        _updated = os.epoch("utc")
    }
end

function M.add(entries, candidates, wantedKey)
    wantedKey = tostring(wantedKey or "")
    if wantedKey == "" then return nil, "door candidate key is required" end
    for _, entry in ipairs(entries or {}) do
        local key = entry.key or M.key(entry.source, entry.target, entry.side)
        if key == wantedKey then return nil, "door is already configured" end
    end

    local selected
    for _, candidate in ipairs(candidates or {}) do if candidate.key == wantedKey then selected = candidate; break end end
    if not selected then return nil, "door candidate is no longer online" end

    local nextId = 1
    for _, entry in ipairs(entries or {}) do nextId = math.max(nextId, (tonumber(entry.id) or 0) + 1) end
    local entry = {
        id = nextId,
        name = selected.localName or string.format("DOOR %02d", nextId),
        key = selected.key,
        source = tostring(selected._source or "server"),
        target = selected.target,
        side = selected.side,
        kind = selected.kind,
        type = selected.type,
        controller = selected.controller,
        mode = selected.mode
    }
    entries[#entries + 1] = entry
    return entry
end

function M.remove(entries, id)
    id = tonumber(id)
    if not id then return nil, "door id is required" end
    for index, entry in ipairs(entries or {}) do
        if tonumber(entry.id) == id then table.remove(entries, index); return entry end
    end
    return nil, "configured door was not found"
end

function M.path() return PATH end

return M