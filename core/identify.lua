local M={}

local function isMonitor(name)
 local ok,t=pcall(peripheral.getType,name);if ok and t=="monitor"then return true end
 if type(peripheral.hasType)=="function"then local ok2,v=pcall(peripheral.hasType,name,"monitor");if ok2 and v then return true end end
 return false
end
local function center(t,y,text)
 local ok,w=pcall(t.getSize);w=ok and tonumber(w)or 40;text=tostring(text or"")
 pcall(t.setCursorPos,math.max(1,math.floor((w-#text)/2)+1),y);pcall(t.write,text)
end
local function paint(t,cfg,role)
 pcall(t.setBackgroundColor,colors.black);pcall(t.setTextColor,colors.lime);pcall(t.clear)
 center(t,2,"=== KIMI IDENTIFY ===");pcall(t.setTextColor,colors.white)
 center(t,5,tostring(cfg and cfg.name or("KIMI-"..os.getComputerID())):upper())
 center(t,7,"COMPUTER ID "..tostring(os.getComputerID()))
 center(t,9,tostring(role or cfg and cfg.role or"KIMI"):upper())
 pcall(t.setTextColor,colors.yellow);center(t,12,"THIS ONE, BRO")
 pcall(t.setTextColor,colors.white)
end
function M.paint(cfg,role)
 paint(term,cfg,role)
 local ok,names=pcall(peripheral.getNames);if ok and type(names)=="table"then
  for _,name in ipairs(names)do if isMonitor(name)then local okw,m=pcall(peripheral.wrap,name);if okw and m then pcall(m.setTextScale,1);paint(m,cfg,role)end end end
 end
end
return M
