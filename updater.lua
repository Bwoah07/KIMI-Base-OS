-- KIMI Base OS low-space transactional updater / recovery tool
local OWNER, REPO, BRANCH = "Bwoah07", "KIMI-Base-OS", "main"
local RAW_ROOT = "https://raw.githubusercontent.com/" .. OWNER .. "/" .. REPO .. "/"
local API_HEAD = "https://api.github.com/repos/" .. OWNER .. "/" .. REPO .. "/commits/" .. BRANCH
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
    local f = fs.open(path, "r"); if not f then return nil end
    local data = f.readAll(); f.close(); return data
end
local function writeFile(path,data)
    ensureParent(path)
    local f,err = fs.open(path,"w")
    if not f then error(err or ("unable to write "..path)) end
    f.write(data); f.close()
end
local function nonce() return tostring(os.epoch("utc")).."-"..tostring(math.random(100000,999999)) end
local function clearPath(path) if fs.exists(path) then fs.delete(path) end end
local function makeCleanDir(path) clearPath(path); fs.makeDir(path) end
local function copyFile(src,dst)
    ensureParent(dst); if fs.exists(dst) then fs.delete(dst) end; fs.copy(src,dst)
end
local function getHeadSha()
    local headers={ ["User-Agent"]="KIMI-Base-OS", ["Accept"]="application/vnd.github+json" }
    local r,err=http.get(API_HEAD.."?kimi_cb="..textutils.urlEncode(nonce()),headers)
    if not r then return nil,err end
    local body=r.readAll(); r.close(); local obj=body and textutils.unserializeJSON(body) or nil
    if type(obj)~="table" or type(obj.sha)~="string" or obj.sha=="" then return nil,"invalid GitHub head response" end
    return obj.sha
end
local function fetchFrom(ref,path)
    local r,err=http.get(RAW_ROOT..tostring(ref).."/"..path.."?kimi_cb="..textutils.urlEncode(nonce()))
    if not r then return nil,err end
    local body=r.readAll(); r.close(); if not body or body=="" then return nil,"empty response for "..path end
    return body
end
local function decodeManifest(raw)
    local m=raw and textutils.unserializeJSON(raw) or nil
    if type(m)~="table" or type(m.version)~="string" or type(m.managed)~="table" then return nil,"invalid manifest" end
    return m
end
local function validManifest(m)
    return type(m)=="table" and type(m.version)=="string" and type(m.managed)=="table" and type(m.ref)=="string" and m.ref~=""
end
local function validateLua(path,body)
    if path:sub(-4)~=".lua" then return true end
    local fn,err=load(body,"@"..path); if not fn then return false,err end; return true
end
local function localVersion() return ((readFile("version.txt") or "not-installed"):gsub("%s+$","")) end
local function readRequest()
    local raw=readFile(REQUESTED); local req=raw and textutils.unserialize(raw) or nil; return type(req)=="table" and req or nil
end
local function rollback()
    local stateRaw=readFile(BACKUP.."/state"); local state=stateRaw and textutils.unserialize(stateRaw) or nil
    if type(state)~="table" or type(state.files)~="table" then print("[KIMI] no rollback snapshot available"); return false end
    print("[KIMI] restoring "..tostring(state.version or "previous version").."...")
    for _,item in ipairs(state.files) do
        if fs.exists(item.path) and not fs.isDir(item.path) then fs.delete(item.path) end
        if item.existed then local src=BACKUP.."/files/"..item.path; if fs.exists(src) then copyFile(src,item.path) end end
    end
    local old=readFile(BACKUP.."/installed_manifest.json"); if old then writeFile(INSTALLED_MANIFEST,old) end
    clearPath(PENDING); clearPath(REQUESTED); print("[KIMI] rollback complete"); return true
end
local function freeSpace()
    local ok,v=pcall(fs.getFreeSpace,"/"); if ok then return v end
end
local function sameBody(path,body) return readFile(path)==body end

if not fs.exists(ROOT) then fs.makeDir(ROOT) end
if mode=="rollback" then if rollback() then return else error("rollback unavailable") end end

-- A pending build owns the rollback snapshot until probation succeeds.
if fs.exists(PENDING) and mode~="force" then
    print("[KIMI] update probation pending; keeping rollback snapshot")
    return
end

if mode=="auto" then print("[KIMI] checking for requested/server release...") end
local requested=readRequest(); local headSha,manifestRaw,manifest; local authorityPinned=false
if mode=="auto" and requested and requested.target then
    if validManifest(requested.manifest) and tostring(requested.manifest.version)==tostring(requested.target) then
        manifest=requested.manifest; manifestRaw=textutils.serializeJSON(manifest); headSha=manifest.ref; authorityPinned=true
        print("[KIMI] using server-authority release "..tostring(manifest.version))
    elseif requested.manifest~=nil then print("[KIMI] requested release manifest invalid; keeping installed version"); return end
end
if not manifest then
    headSha=getHeadSha(); if not headSha then print("[KIMI] update check skipped: GitHub unavailable"); return end
    local err; manifestRaw,err=fetchFrom(headSha,"manifest.json")
    if not manifestRaw then print("[KIMI] update check skipped: "..tostring(err)); return end
    local decodeErr; manifest,decodeErr=decodeManifest(manifestRaw); if not manifest then error(decodeErr) end
end
local current=localVersion(); local releaseRef=manifest.ref or headSha
print("[KIMI] local "..current.." / remote "..tostring(manifest.version))
print("[KIMI] release ref: "..tostring(releaseRef)..(authorityPinned and " (server authority)" or ""))
if mode=="check" then print(current==manifest.version and ("KIMI is up to date: "..current) or ("KIMI update available: "..current.." -> "..manifest.version)); return end
if current==manifest.version and mode~="force" then clearPath(REQUESTED); print("[KIMI] up to date: "..current); return end

print("[KIMI] updating "..current.." -> "..manifest.version)
-- Old rollback data is only useful while PENDING exists. At this point it is stale
-- and must not compete with the next release for ComputerCraft's tiny disk.
clearPath(BACKUP); makeCleanDir(STAGE)

local changed,changedSet={},{}
local stageOk,stageErr=pcall(function()
    for _,path in ipairs(manifest.managed) do
        write("Download "..path.." ... ")
        local body,err=fetchFrom(releaseRef,path); if not body then error(tostring(err)) end
        local valid,syntaxErr=validateLua(path,body); if not valid then error(path..": "..tostring(syntaxErr)) end
        if sameBody(path,body) then
            print("SAME")
        else
            writeFile(STAGE.."/"..path,body); changed[#changed+1]=path; changedSet[path]=true; print("OK")
        end
    end
end)
if not stageOk then clearPath(STAGE); error("update download/stage failed: "..tostring(stageErr)) end

local removals={}
for _,path in ipairs(manifest.remove or {}) do if fs.exists(path) and not fs.isDir(path) then removals[#removals+1]=path end end
print("[KIMI] delta: "..#changed.." changed / "..#removals.." removed")
local free=freeSpace(); if free then print("[KIMI] free space before backup: "..tostring(free)) end

makeCleanDir(BACKUP); fs.makeDir(BACKUP.."/files")
local backupState={version=current,files={}}
local function backup(path)
    local existed=fs.exists(path) and not fs.isDir(path)
    backupState.files[#backupState.files+1]={path=path,existed=existed}
    if existed then copyFile(path,BACKUP.."/files/"..path) end
end
local backupOk,backupErr=pcall(function()
    for _,path in ipairs(changed) do backup(path) end
    for _,path in ipairs(removals) do if not changedSet[path] then backup(path) end end
    writeFile(BACKUP.."/state",textutils.serialize(backupState))
    local old=readFile(INSTALLED_MANIFEST); if old then writeFile(BACKUP.."/installed_manifest.json",old) end
end)
if not backupOk then clearPath(STAGE); clearPath(BACKUP); error("update backup failed (free disk space): "..tostring(backupErr)) end

local ok,installErr=pcall(function()
    for _,path in ipairs(removals) do if fs.exists(path) and not fs.isDir(path) then fs.delete(path) end end
    for _,path in ipairs(changed) do
        local staged=STAGE.."/"..path; ensureParent(path); if fs.exists(path) then fs.delete(path) end; fs.move(staged,path)
    end
    writeFile(INSTALLED_MANIFEST,manifestRaw)
    writeFile("version.txt",manifest.version.."\n")
    writeFile(PENDING,textutils.serialize({from=current,to=manifest.version,ref=releaseRef,discoveryHead=authorityPinned and "server-authority" or headSha,installed=os.epoch("utc"),crashes=0}))
end)
if not ok then print("[KIMI] install failed; rolling back..."); rollback(); error("update rolled back: "..tostring(installErr)) end
clearPath(STAGE); clearPath(REQUESTED)
print("[KIMI] update staged successfully; probation boot required")
