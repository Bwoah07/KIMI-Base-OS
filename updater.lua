-- KIMI Base OS updater
local OWNER = "Bwoah07"
local REPO = "KIMI-Base-OS"
local BRANCH = "main"
local BASE = "https://raw.githubusercontent.com/" .. OWNER .. "/" .. REPO .. "/" .. BRANCH .. "/"

local files = {
    "version.txt",
    "startup.lua",
    "server.lua",
    "client.lua",
    "lib/environment.lua",
    "lib/network.lua"
}

local function ensureDir(path)
    local dir = fs.getDir(path)
    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end
end

local function fetch(path)
    local response, err = http.get(BASE .. path)
    if not response then
        return nil, err
    end
    local body = response.readAll()
    response.close()
    return body
end

local function readLocal(path)
    if not fs.exists(path) then return nil end
    local f = fs.open(path, "r")
    local data = f.readAll()
    f.close()
    return data
end

local remoteVersion, versionErr = fetch("version.txt")
if not remoteVersion then
    error("Could not check KIMI update: " .. tostring(versionErr))
end
remoteVersion = remoteVersion:gsub("%s+$", "")

local localVersion = (readLocal("version.txt") or "not installed"):gsub("%s+$", "")
print("KIMI Base OS")
print("Local:  " .. localVersion)
print("Remote: " .. remoteVersion)

if localVersion == remoteVersion and not ({...})[1] then
    print("Already up to date.")
    return
end

for _, path in ipairs(files) do
    write("Updating " .. path .. " ... ")
    local body, err = fetch(path)
    if not body then
        print("FAILED")
        error(tostring(err))
    end

    ensureDir(path)
    local tmp = path .. ".new"
    local f = fs.open(tmp, "w")
    f.write(body)
    f.close()

    if fs.exists(path) then fs.delete(path) end
    fs.move(tmp, path)
    print("OK")
end

print("KIMI updated to " .. remoteVersion)
