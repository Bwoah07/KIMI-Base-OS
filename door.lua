local args = {...}
local cmd = tostring(args[1] or "help"):lower()
local ROOT = ".kimi"
local LEGACY_FLAG = ROOT .. "/door_setup_request"

local function clearLegacyFlag()
  if fs.exists(LEGACY_FLAG) and not fs.isDir(LEGACY_FLAG) then fs.delete(LEGACY_FLAG) end
end

if cmd == "setup" then
  clearLegacyFlag()
  if not fs.exists("door_setup.lua") then error("door_setup.lua is not installed") end
  shell.run("door_setup")
elseif cmd == "cancel" then
  clearLegacyFlag()
  print("[KIMI] legacy door setup request cleared")
else
  print("KIMI door command")
  print("  door setup   - open standalone touchscreen door setup")
  print("  door cancel  - clear an old pending setup request")
end
