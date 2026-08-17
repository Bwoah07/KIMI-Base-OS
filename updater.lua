-- KIMI Base OS transactional updater
local OWNER, REPO, BRANCH = "Bwoah07", "KIMI-Base-OS", "main"
local BASE = "https://raw.githubusercontent.com/" .. OWNER .. "/" .. REPO .. "/" .. BRANCH .. "/"
local ROOT = ".kimi"
local STAGE = ROOT .. "/staging"
local BACKUP = ROOT .. "/rollback"

local function fetch(path)
    local r, err = http.get(BASE .. path)
    if not r then return nil, err end
    local body = r.readAll()
    r.close()
    if not body or body == "" then return nil, "empty response for " .. path end
    return body
end

local function ensureParent(path)
    local dir = fs.getDir(path)
    if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
end

local function writeFile(path, body)
    ensureParent(path)
    local f = assert(fs.open(path, "w"))
    f.write(body)
    f.close()
end

local function copyFile(src, dst)
    ensureParent(dst)
    if fs.exists(dst) then fs.delete(dst) end
    fs.copy(src, dst)
end

local function clearDir(path)
    if fs.exists(path) then fs.delete(path) end
    fs.makeDir(path)
end

local manifestRaw, manifestErr = fetch("manifest.json")
if not manifestRaw then error("Manifest download failed: " .. tostring(manifestErr)) end
local manifest = textutils.unserializeJSON(manifestRaw)
if type(manifest) ~= "table" or type(manifest.managed) ~= "table" or not manifest.version then
    error("Invalid KIMI manifest")
end

print("KIMI Base OS updater")
print("Target: " .. tostring(manifest.version))

if not fs.exists(ROOT) then fs.makeDir(ROOT) end
clearDir(STAGE)

-- Phase 1: download EVERYTHING before touching the live install.
for _, path in ipairs(manifest.managed) do
    write("Download " .. path .. " ... ")
    local body, err = fetch(path)
    if not body then
        print("FAILED")
        fs.delete(STAGE)
        error(tostring(err))
    end
    writeFile(fs.combine(STAGE, path), body)
    print("OK")
end

-- Phase 2: snapshot currently installed managed files.
clearDir(BACKUP)
for _, path in ipairs(manifest.managed) do
    if fs.exists(path) and not fs.isDir(path) then
        copyFile(path, fs.combine(BACKUP, path))
    end
end

-- Phase 3: install staged files. If this fails, restore snapshot.
local ok, installErr = pcall(function()
    for _, path in ipairs(manifest.managed) do
        local staged = fs.combine(STAGE, path)
        ensureParent(path)
        if fs.exists(path) then fs.delete(path) end
        fs.move(staged, path)
    end
    writeFile("version.txt", tostring(manifest.version) .. "\n")
end)

if not ok then
    print("Update failed - restoring previous install...")
    for _, path in ipairs(manifest.managed) do
        local backup = fs.combine(BACKUP, path)
        if fs.exists(backup) then
            if fs.exists(path) then fs.delete(path) end
            copyFile(backup, path)
        end
    end
    error("Update rolled back: " .. tostring(installErr))
end

if fs.exists(STAGE) then fs.delete(STAGE) end
print("KIMI updated successfully to " .. tostring(manifest.version))
