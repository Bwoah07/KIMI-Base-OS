-- KIMI Base OS recovery bootloader
local ROOT = ".kimi"
local PENDING = ROOT .. "/update_pending"
local REQUESTED = ROOT .. "/update_requested"
local RELOAD = ROOT .. "/reload_requested"
local BACKUP = ROOT .. "/rollback"
local CONFIG = ROOT .. "/config"
local UPDATER_URL = "https://raw.githubusercontent.com/Bwoah07/KIMI-Base-OS/main/updater.lua"

local function readFile(path)
    if not fs.exists(path) or fs.isDir(path) then return nil end
    local f = fs.open(path, "r"); if not f then return nil end
    local data = f.readAll(); f.close(); return data
end
local function writeFile(path, data)
    local dir = fs.getDir(path); if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
    local f = assert(fs.open(path, "w")); f.write(data); f.close()
end
local function readPending() local raw=readFile(PENDING); return raw and textutils.unserialize(raw) or nil end
local function readConfig() local raw=readFile(CONFIG);local cfg=raw and textutils.unserialize(raw)or nil;return type(cfg)=="table"and cfg or{} end

local function refreshUpdaterEmergency()
    local url = UPDATER_URL .. "?kimi_cb=" .. tostring(os.epoch("utc"))
    local r = http.get(url); if not r then return false end
    local body = r.readAll(); r.close(); if not body or body == "" then return false end
    local fn = load(body, "@updater.lua"); if not fn then return false end
    writeFile("updater.lua.new", body); if fs.exists("updater.lua") then fs.delete("updater.lua") end; fs.move("updater.lua.new", "updater.lua"); return true
end

local function directRollback()
    local stateRaw = readFile(BACKUP .. "/state"); local state = stateRaw and textutils.unserialize(stateRaw) or nil
    if type(state) ~= "table" or type(state.files) ~= "table" or state.version == "not-installed" then return false end
    for _, item in ipairs(state.files) do
        if fs.exists(item.path) and not fs.isDir(item.path) then fs.delete(item.path) end
        if item.existed then
            local src=BACKUP.."/files/"..item.path
            if fs.exists(src) then local dir=fs.getDir(item.path);if dir~=""and not fs.exists(dir)then fs.makeDir(dir)end;fs.copy(src,item.path)end
        end
    end
    local oldManifest=readFile(BACKUP.."/installed_manifest.json");if oldManifest then writeFile(ROOT.."/installed_manifest.json",oldManifest)end
    if fs.exists(PENDING)then fs.delete(PENDING)end;if fs.exists(REQUESTED)then fs.delete(REQUESTED)end;if fs.exists(RELOAD)then fs.delete(RELOAD)end
    return true
end

local function tryUpdate()
    if not fs.exists("updater.lua") then pcall(refreshUpdaterEmergency) end
    if not fs.exists("updater.lua") then return end
    local ok,result=pcall(function()return shell.run("updater","auto")end)
    if not ok or result==false then term.setTextColor(colors.yellow);print("[KIMI] update unavailable/failed; booting installed version");term.setTextColor(colors.white) end
end

if not fs.exists(ROOT) then fs.makeDir(ROOT) end
local cfg=readConfig();local role=cfg.role or"client";local updateCfg=type(cfg.update)=="table"and cfg.update or{}
local requested=fs.exists(REQUESTED);local bootCheck=role=="server"and updateCfg.auto~=false and updateCfg.checkOnBoot~=false
if requested or bootCheck then tryUpdate() end

while true do
    term.setBackgroundColor(colors.black);term.setTextColor(colors.white)
    local ok,ran=pcall(function()return shell.run("kimi")end)

    -- A live update deliberately exits KIMI. This is not a crash and must not
    -- consume probation retries. Restart immediately in a fresh program env.
    if fs.exists(RELOAD) then
        fs.delete(RELOAD)
        term.setTextColor(colors.lime);print("[KIMI] live reload -> fresh runtime");term.setTextColor(colors.white)
        sleep(0.05)
    else
        local pending=readPending()
        if pending then
            pending.crashes=(tonumber(pending.crashes)or 0)+1;writeFile(PENDING,textutils.serialize(pending))
            if pending.crashes>=3 then
                term.setTextColor(colors.red)
                if tostring(pending.from)=="not-installed"then print("[KIMI] first install failed probation; no older OS exists to restore")
                else
                    print("[KIMI] new build failed probation 3 times; restoring last known-good OS...");term.setTextColor(colors.white)
                    if directRollback()then print("[KIMI] rollback restored; rebooting");sleep(1);os.reboot()else print("[KIMI] rollback snapshot unavailable; retrying installed build")end
                end
                term.setTextColor(colors.white)
            end
        end
        term.setTextColor(colors.red);print("[KIMI] kernel stopped"..((ok and ran~=false)and""or" unexpectedly"));term.setTextColor(colors.white)
        print("[KIMI] restarting in 3s...");sleep(3)
    end
end
