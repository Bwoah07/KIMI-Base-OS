-- KIMI Base OS one-time bootstrap installer
local RAW = "https://raw.githubusercontent.com/Bwoah07/KIMI-Base-OS/main/"

local function get(url,path)
    local sep=url:find("?",1,true) and "&" or "?"; url=url..sep.."kimi_cb="..tostring(os.epoch("utc"))
    local r,err=http.get(url); if not r then return false,err end
    local body=r.readAll(); r.close(); if not body or body=="" then return false,"empty response" end
    if path:sub(-4)==".lua" then local fn,syntaxErr=load(body,"@"..path); if not fn then return false,syntaxErr end end
    local dir=fs.getDir(path); if dir~="" and not fs.exists(dir) then fs.makeDir(dir) end
    local f=assert(fs.open(path,"w")); f.write(body); f.close(); return true
end

local function hasMonitor()
    if type(peripheral)~="table"or type(peripheral.getNames)~="function"then return false end
    local ok,names=pcall(peripheral.getNames);if not ok or type(names)~="table"then return false end
    for _,name in ipairs(names)do
        local okt,t=pcall(peripheral.getType,name);if okt and t=="monitor"then return true end
        if type(peripheral.hasType)=="function"then local okh,v=pcall(peripheral.hasType,name,"monitor");if okh and v then return true end end
    end
    return false
end

term.clear(); term.setCursorPos(1,1); term.setTextColor(colors.red); print("KIMI BASE OS"); term.setTextColor(colors.white)
print("One-time bootstrap installer\n")
print("1) Server + Command Center monitors")
print("2) Server only (headless)")
print("3) Client (auto/manual monitor layout)")
print("4) Pocket computer")
print("5) Remote sensor / machine node")
write("> "); local choice=read()

local role,profile,localUI,nodeCfg
if choice=="1" then role,profile,localUI="server","admin",true
elseif choice=="2" then role,profile,localUI="server","terminal",false
elseif choice=="3" then role,profile,localUI="client","wall",false
elseif choice=="4" then role,profile,localUI="client","pocket",false
elseif choice=="5" then role,profile,localUI="node","node",false; nodeCfg={publishInterval=2}
else error("Invalid choice") end

local defaultName=(type(os.getComputerLabel)=="function"and os.getComputerLabel())or("KIMI-"..tostring(os.getComputerID()))
write("Computer name ["..tostring(defaultName).."]: ");local entered=read();local computerName=(entered and entered:match("%S"))and entered or defaultName
if type(os.setComputerLabel)=="function"then pcall(os.setComputerLabel,computerName)end

if not fs.exists(".kimi") then fs.makeDir(".kimi") end
local cfg={role=role,profile=profile,localUI=localUI,name=computerName,theme={accent="red"},network={protocol="kimi_base_os_v1",hostname="kimi-base"},update={channel="alpha",auto=true,fleetManaged=true,checkOnBoot=true,interval=600},node=nodeCfg}
local f=assert(fs.open(".kimi/config","w")); f.write(textutils.serialize(cfg)); f.close()

print("\nName: "..computerName)
print("Role: "..role.." / "..profile)
if localUI then print("Local command-center admin UI: enabled") end
if role=="server" then print("This machine is the fleet update authority.") else print("Fleet-managed updates: enabled") end
print("Door setup is separate: run 'door setup' only on computers which actually own a door controller.")

print("\nInstalling recovery bootloader...")
local ok,err=get(RAW.."startup.lua","startup.lua"); if not ok then error("Cannot install recovery bootloader: "..tostring(err)) end
print("Downloading updater...")
ok,err=get(RAW.."updater.lua","updater.lua"); if not ok then error("Cannot download updater: "..tostring(err)) end
print("Installing KIMI OS...")
local installed=shell.run("updater","force"); if installed==false then error("KIMI OS installation failed") end

if role~="node"and profile~="pocket"and hasMonitor()and fs.exists("setup.lua")then
    print("\nConfigure attached monitor views now? [Y/n]")
    write("> ");local answer=tostring(read()or""):lower()
    if answer==""or answer=="y"or answer=="yes"then shell.run("setup","monitors")end
end

print("\nInstalled. Rebooting..."); sleep(1); os.reboot()
