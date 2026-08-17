-- KIMI Base OS one-time bootstrap installer
local RAW = "https://raw.githubusercontent.com/Bwoah07/KIMI-Base-OS/main/"

local function get(url, path)
    local r, err = http.get(url)
    if not r then return false, err end
    local body = r.readAll(); r.close()
    if not body or body == "" then return false, "empty response" end
    if path:sub(-4) == ".lua" then
        local fn, syntaxErr = load(body, "@" .. path)
        if not fn then return false, syntaxErr end
    end
    local dir = fs.getDir(path)
    if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
    local f = assert(fs.open(path, "w")); f.write(body); f.close()
    return true
end

term.clear()
term.setCursorPos(1, 1)
term.setTextColor(colors.red)
print("KIMI BASE OS")
term.setTextColor(colors.white)
print("One-time bootstrap installer\n")
print("1) Base server")
print("2) Wall / room display")
print("3) Pocket computer")
write("> ")
local choice = read()

local role, profile
if choice == "1" then role, profile = "server", "terminal"
elseif choice == "2" then role, profile = "client", "wall"
elseif choice == "3" then role, profile = "client", "pocket"
else error("Invalid choice") end

if not fs.exists(".kimi") then fs.makeDir(".kimi") end
local cfg = {
    role = role,
    profile = profile,
    name = "KIMI-" .. tostring(os.getComputerID()),
    theme = { accent = "red" },
    network = { protocol = "kimi_base_os_v1", hostname = "kimi-base" },
    update = { channel = "alpha", auto = true, checkOnBoot = true, interval = 600 }
}
local f = assert(fs.open(".kimi/config", "w"))
f.write(textutils.serialize(cfg)); f.close()

print("\nInstalling recovery bootloader...")
local ok, err = get(RAW .. "startup.lua", "startup.lua")
if not ok then error("Cannot install recovery bootloader: " .. tostring(err)) end

print("Downloading updater...")
ok, err = get(RAW .. "updater.lua", "updater.lua")
if not ok then error("Cannot download updater: " .. tostring(err)) end

print("Installing KIMI OS...")
local installed = shell.run("updater", "force")
if installed == false then error("KIMI OS installation failed") end

print("\nInstalled. Rebooting...")
sleep(2)
os.reboot()
