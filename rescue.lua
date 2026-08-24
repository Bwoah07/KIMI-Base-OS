-- KIMI one-shot rescue/bootstrap for low-space updater failures.
-- Safe to run on a stable installed KIMI system. It clears transient update data,
-- prunes legacy UI generations, refreshes updater.lua from main, and retries.
local ROOT = ".kimi"
local RAW = "https://raw.githubusercontent.com/Bwoah07/KIMI-Base-OS/main/updater.lua"

local function rm(path)
  if fs.exists(path) then fs.delete(path) end
end

local function writeFile(path, body)
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  local f = assert(fs.open(path, "w")); f.write(body); f.close()
end

term.setTextColor(colors.yellow)
print("[KIMI] rescue: freeing update workspace...")
term.setTextColor(colors.white)
rm(ROOT .. "/staging")
rm(ROOT .. "/rollback")
rm("updater.lua.new")
for _,path in ipairs({
  "clients/adaptive.lua",
  "clients/adaptive_v2.lua",
  "clients/adaptive_v3.lua",
  "clients/adaptive_v4.lua",
  "clients/adaptive_v5.lua",
  "clients/adaptive_v6.lua"
}) do rm(path) end

print("[KIMI] rescue: refreshing updater...")
local r, err = http.get(RAW .. "?kimi_cb=" .. tostring(os.epoch("utc")))
if not r then error("unable to download updater: " .. tostring(err)) end
local body = r.readAll(); r.close()
local fn, syntaxErr = load(body, "@updater.lua")
if not fn then error("downloaded updater is invalid: " .. tostring(syntaxErr)) end
writeFile("updater.lua.new", body)
rm("updater.lua")
fs.move("updater.lua.new", "updater.lua")

print("[KIMI] rescue: retrying update...")
local ok = shell.run("updater", "auto")
if ok == false then error("updater reported failure") end
print("[KIMI] rescue complete; rebooting")
sleep(1)
os.reboot()
