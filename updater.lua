-- KIMI Base OS transactional updater / recovery tool
local OWNER, REPO, BRANCH = "Bwoah07", "KIMI-Base-OS", "main"
local RAW_ROOT = "https://raw.githubusercontent.com/" .. OWNER .. "/" .. REPO .. "/"
local ROOT = ".kimi"
local STAGE = ROOT .. "/staging"
local BACKUP = ROOT .. "/rollback"
local INSTALLED_MANIFEST = ROOT .. "/installed_manifest.json"
local PENDING = ROOT .. "/update_pending"
local REQUESTED = ROOT .. "/update_requested"
local mode = ({...})[1] or "auto"

local function ensureParent(path)
    local dir = fs.getDir(path)
    if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
end

local function readFile(path)
    if not fs.exists(path) or fs.isDir(path) then return nil end
    local f = fs.open(path, "r")
    if not f then return nil end
    local data = f.readAll(); f.close(); return data
end

local function writeFile(path, data)
    ensureParent(path)
    local f = assert(fs.open(path, "w")); f.write(data); f.close()
end

local function nonce()
    return tostring(os.epoch("utc")) .. "-" .. tostring(math.random(100000, 999999))
end

local function fetchFrom(ref, path)
    local url = RAW_ROOT .. tostring(ref) .. "/" .. path .. "?kimi_cb=" .. textutils.urlEncode(nonce())
    local r, err = http.get(url)
    if not r then return nil, err end
    local body = r.readAll(); r.close()
    if not body or body == "" then return nil, "empty response for " .. path end
    return body
end

local function decodeManifest(raw)
    local m = raw and textutils.unserializeJSON(raw) or nil
    if type(m) ~= "table" or type(m.version) ~= "string" or type(m.managed) ~= "table" then
        return nil, "invalid manifest"
    end
    return m
end

local function localVersion()
    return ((readFile("version.txt") or "not-installed"):gsub("%s+$", ""))
end

local function clearDir(path)
    if fs.exists(path) then fs.delete(path) end
    fs.makeDir(path)
end

local function copyFile(src, dst)
    ensureParent(dst)
    if fs.exists(dst) then fs.delete(dst) end
    fs.copy(src, dst)
end

local function validateLua(path, body)
    if path:sub(-4) ~= ".lua" then return true end
    local fn, err = load(body, "@" .. path)
    if not fn then return false, err end
    return true
end

local function listUnion(oldManifest, newManifest)
    local seen, out = {}, {}
    local function add(list)
        for _, path in ipairs(list or {}) do
            if not seen[path] then seen[path] = true; out[#out + 1] = path end
        end
    end
    add(oldManifest and oldManifest.managed)
    add(newManifest and newManifest.managed)
    add(newManifest and newManifest.remove)
    return out
end

local function rollback()
    local stateRaw = readFile(BACKUP .. "/state")
    local state = stateRaw and textutils.unserialize(stateRaw) or nil
    if type(state) ~= "table" or type(state.files) ~= "table" then
        print("[KIMI] no rollback snapshot available")
        return false
    end

    print("[KIMI] restoring " .. tostring(state.version or "previous version") .. "...")
    for _, item in ipairs(state.files) do
        if fs.exists(item.path) then fs.delete(item.path) end
        if item.existed then
            local backupPath = BACKUP .. "/files/" .. item.path
            if fs.exists(backupPath) then copyFile(backupPath, item.path) end
        end
    end

    local oldManifest = readFile(BACKUP .. "/installed_manifest.json")
    if oldManifest then writeFile(INSTALLED_MANIFEST, oldManifest) end
    if fs.exists(PENDING) then fs.delete(PENDING) end
    if fs.exists(REQUESTED) then fs.delete(REQUESTED) end
    print("[KIMI] rollback complete")
    return true
end

if not fs.exists(ROOT) then fs.makeDir(ROOT) end
if mode == "rollback" then
    if rollback() then return else error("rollback unavailable") end
end

if mode == "auto" then print("[KIMI] checking GitHub for updates...") end

local manifestRaw, manifestErr = fetchFrom(BRANCH, "manifest.json")
if not manifestRaw then
    if mode == "auto" or mode == "check" then
        print("[KIMI] update check skipped: " .. tostring(manifestErr))
        return
    end
    error("manifest download failed: " .. tostring(manifestErr))
end

local manifest, manifestDecodeErr = decodeManifest(manifestRaw)
if not manifest then error(manifestDecodeErr) end
local current = localVersion()
local releaseRef = manifest.ref or BRANCH

print("[KIMI] local " .. current .. " / remote " .. tostring(manifest.version))

if mode == "check" then
    if current == manifest.version then print("KIMI is up to date: " .. current)
    else print("KIMI update available: " .. current .. " -> " .. manifest.version) end
    return
end

if current == manifest.version and mode ~= "force" then
    if fs.exists(REQUESTED) then fs.delete(REQUESTED) end
    print("[KIMI] up to date: " .. current)
    return
end

print("[KIMI] updating " .. current .. " -> " .. manifest.version)
print("[KIMI] release ref: " .. tostring(releaseRef))
clearDir(STAGE)

-- Every managed file is fetched from the immutable release commit when manifest.ref exists.
for _, path in ipairs(manifest.managed) do
    write("Download " .. path .. " ... ")
    local body, err = fetchFrom(releaseRef, path)
    if not body then fs.delete(STAGE); print("FAILED"); error(tostring(err)) end
    local valid, syntaxErr = validateLua(path, body)
    if not valid then fs.delete(STAGE); print("INVALID"); error(path .. ": " .. tostring(syntaxErr)) end
    writeFile(STAGE .. "/" .. path, body)
    print("OK")
end

local oldManifest = decodeManifest(readFile(INSTALLED_MANIFEST) or "")
local affected = listUnion(oldManifest, manifest)
clearDir(BACKUP)
fs.makeDir(BACKUP .. "/files")
local backupState = { version = current, files = {} }

for _, path in ipairs(affected) do
    local existed = fs.exists(path) and not fs.isDir(path)
    backupState.files[#backupState.files + 1] = { path = path, existed = existed }
    if existed then copyFile(path, BACKUP .. "/files/" .. path) end
end
writeFile(BACKUP .. "/state", textutils.serialize(backupState))
local oldManifestRaw = readFile(INSTALLED_MANIFEST)
if oldManifestRaw then writeFile(BACKUP .. "/installed_manifest.json", oldManifestRaw) end

local ok, installErr = pcall(function()
    local keep = {}; for _, p in ipairs(manifest.managed) do keep[p] = true end
    for _, path in ipairs(affected) do
        if not keep[path] and fs.exists(path) and not fs.isDir(path) then fs.delete(path) end
    end

    for _, path in ipairs(manifest.managed) do
        local staged = STAGE .. "/" .. path
        ensureParent(path)
        if fs.exists(path) then fs.delete(path) end
        fs.copy(staged, path)
    end

    writeFile(INSTALLED_MANIFEST, manifestRaw)
    writeFile("version.txt", manifest.version .. "\n")
    writeFile(PENDING, textutils.serialize({
        from = current,
        to = manifest.version,
        ref = releaseRef,
        installed = os.epoch("utc"),
        crashes = 0
    }))
end)

if not ok then
    print("[KIMI] install failed; rolling back...")
    rollback()
    error("update rolled back: " .. tostring(installErr))
end

if fs.exists(STAGE) then fs.delete(STAGE) end
if fs.exists(REQUESTED) then fs.delete(REQUESTED) end
print("[KIMI] update staged successfully; probation boot required")
