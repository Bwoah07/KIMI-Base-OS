-- Install the KIMI Base OS bridge around an existing cc-mek-scada computer.

local OWNER, REPO, BRANCH = "Bwoah07", "KIMI-Base-OS", "main"
local REPO_PATH = "scada/kimi_scada_boot.lua"
local ROOT = "/.kimi-scada"
local APPS = { "reactor-plc", "rtu", "supervisor", "coordinator", "pocket" }

local function detectApp()
    for _, app in ipairs(APPS) do
        if fs.exists("/" .. app .. "/startup.lua") then return app end
    end
end

local function writeFile(path, data)
    local dir = fs.getDir(path)
    if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
    local f = assert(fs.open(path, "w"))
    f.write(data)
    f.close()
end

local function httpJSON(url, headers)
    local r, err = http.get(url, headers)
    if not r then return nil, err end
    local body = r.readAll(); r.close()
    local ok, obj = pcall(textutils.unserializeJSON, body)
    if not ok or type(obj) ~= "table" then return nil, "invalid JSON" end
    return obj
end

local function fetchText(url)
    local r, err = http.get(url)
    if not r then return nil, err end
    local body = r.readAll(); r.close()
    if not body or body == "" then return nil, "empty response" end
    return body
end

local app = detectApp()
if not app then
    error("No cc-mek-scada app found. Install reactor-plc/rtu/supervisor/coordinator first.", 0)
end

if not fs.exists(ROOT) then fs.makeDir(ROOT) end

if fs.exists("/startup.lua") and not fs.exists(ROOT .. "/upstream_startup.lua") then
    fs.copy("/startup.lua", ROOT .. "/upstream_startup.lua")
end

local api = "https://api.github.com/repos/" .. OWNER .. "/" .. REPO .. "/commits/" .. BRANCH
local headers = { ["User-Agent"] = "KIMI-SCADA-Bridge", ["Accept"] = "application/vnd.github+json" }
local head, err = httpJSON(api .. "?kimi_cb=" .. tostring(os.epoch("utc")), headers)
if not head or type(head.sha) ~= "string" then error("KIMI GitHub lookup failed: " .. tostring(err), 0) end

local url = "https://raw.githubusercontent.com/" .. OWNER .. "/" .. REPO .. "/" .. head.sha .. "/" .. REPO_PATH
local body, dlErr = fetchText(url .. "?kimi_cb=" .. tostring(os.epoch("utc")))
if not body then error("Bridge download failed: " .. tostring(dlErr), 0) end

local fn, syntaxErr = load(body, "@startup.lua")
if not fn then error("Downloaded bridge failed syntax validation: " .. tostring(syntaxErr), 0) end

if fs.exists("/startup.lua") then fs.delete("/startup.lua") end
writeFile("/startup.lua", body)
writeFile(ROOT .. "/installed", textutils.serialize({ app = app, installed = os.epoch("utc"), ref = head.sha }))

term.setTextColor(colors.lime)
print("KIMI SCADA bridge installed for " .. app .. ".")
term.setTextColor(colors.white)
print("Reboot this computer to start upstream SCADA + KIMI telemetry.")
