local args = {...}
local cmd = tostring(args[1] or "help"):lower()
local ROOT = ".kimi"
local FLAG = ROOT .. "/door_setup_request"

local function ensureRoot()
  if not fs.exists(ROOT) then fs.makeDir(ROOT) end
end

if cmd == "setup" then
  ensureRoot()
  local f = assert(fs.open(FLAG, "w"))
  f.writeLine("setup")
  f.close()
  print("[KIMI] door setup requested")
  print("[KIMI] rebooting into setup wizard...")
  sleep(0.5)
  os.reboot()
elseif cmd == "cancel" then
  if fs.exists(FLAG) and not fs.isDir(FLAG) then fs.delete(FLAG) end
  print("[KIMI] door setup request cleared")
else
  print("KIMI door command")
  print("  door setup   - reopen the room door setup wizard")
  print("  door cancel  - cancel a pending setup request")
end
