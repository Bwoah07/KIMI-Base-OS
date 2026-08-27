local base=require("clients.room_v17")
local M={}
for k,v in pairs(base)do M[k]=v end

local function identifyActive()
 local untilAt=tonumber(rawget(_G,"kimiIdentifyUntil"))or 0
 local ok,now=pcall(os.epoch,"utc");now=ok and tonumber(now)or 0
 return untilAt>now
end
local function monitors()
 local out={};local ok,names=pcall(peripheral.getNames);if not ok or type(names)~="table"then return out end
 for _,n in ipairs(names)do local is=false;local okT,t=pcall(peripheral.getType,n);if okT and t=="monitor"then is=true elseif type(peripheral.hasType)=="function"then local okH,v=pcall(peripheral.hasType,n,"monitor");is=okH and v==true end;if is then local okW,m=pcall(peripheral.wrap,n);if okW and m then out[#out+1]=m end end end
 return out
end
local function overlay(m)
 pcall(m.setTextScale,1);local ok,w,h=pcall(m.getSize);if not ok then return end
 m.setBackgroundColor(colors.black);m.setTextColor(colors.lime);m.clear()
 local label=tostring(rawget(_G,"kimiIdentifyLabel")or os.getComputerLabel()or"KIMI")
 local id=tostring(rawget(_G,"kimiIdentifyId")or os.getComputerID())
 local function center(y,s,c)s=tostring(s);m.setCursorPos(math.max(1,math.floor((w-#s)/2)+1),y);m.setTextColor(c or colors.white);m.write(s:sub(1,w))end
 center(math.max(2,math.floor(h/2)-3),"*** KIMI IDENTIFY ***",colors.lime)
 center(math.max(3,math.floor(h/2)-1),label,colors.white)
 center(math.max(4,math.floor(h/2)+1),"COMPUTER ID "..id,colors.orange)
 center(math.max(5,math.floor(h/2)+3),"HERE I AM",colors.lime)
end
function M.render(env,meta)
 local ok=base.render(env,meta)
 if identifyActive()then for _,m in ipairs(monitors())do overlay(m)end end
 return ok
end
return M
