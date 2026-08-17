-- KIMI Base OS installer
local OWNER = "Bwoah07"
local REPO = "KIMI-Base-OS"
local BRANCH = "main"
local RAW = "https://raw.githubusercontent.com/" .. OWNER .. "/" .. REPO .. "/" .. BRANCH .. "/"

local function download(url, path)
    local r, err = http.get(url)
    if not r then return false, err end
    local body = r.readAll()
    r.close()
    local f = fs.open(path, "w")
    f.write(body)
    f.close()
    return true
end

term.clear()
term.setCursorPos(1,1)
term.setTextColor(colors.red)
print("KIMI BASE OS INSTALLER")
term.setTextColor(colors.white)
print("")
print("Choose role:")
print("1) Server")
print("2) Wall client")
print("3) Pocket/client")
write("> ")
local choice = read()

local role
if choice == "1" then
    role = "server"
elseif choice == "2" or choice == "3" then
    role = "client"
else
    error("Invalid role")
end

local f = fs.open(".kimi_role", "w")
f.write(role)
f.close()

print("")
print("Downloading updater...")
local ok, err = download(RAW .. "updater.lua", "updater.lua")
if not ok then error("Download failed: " .. tostring(err)) end

print("Installing KIMI files...")
shell.run("updater", "force")

print("")
print("Installation complete.")
print("Rebooting in 2 seconds...")
sleep(2)
os.reboot()
