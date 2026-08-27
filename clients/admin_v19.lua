local base=require("clients.admin_v18")
local M={}
for k,v in pairs(base)do M[k]=v end

local C={bg=colors.black,text=colors.white,dim=colors.lightGray,good=colors.lime,warn=colors.orange}
local function upper(v)return tostring(v or""):upper()end
local function nice(v)return upper(tostring(v or""):gsub("minecraft:",""):gsub("[_%-]"," "):gsub("(%l)(%u)","%1 %2"))end
local function state(env)return env and env.state or{}end
local function isMonitor(n)local ok,t=pcall(peripheral.getType,n);if ok and t=="monitor"then return true end;if type(peripheral.hasType)=="function"then local ok2,v=pcall(peripheral.hasType,n,"monitor");if ok2 and v then return true end end;return false end
local function detectMonitors()local out={};local ok,names=pcall(peripheral.getNames);if not ok or type(names)~="table"then return out end;for _,n in ipairs(names)do if isMonitor(n)then local okW,m=pcall(peripheral.wrap,n);if okW and m then local scale=1;pcall(m.setTextScale,scale);local okS,w,h=pcall(m.getSize);if okS then w,h=tonumber(w),tonumber(h);if w<22 or h<12 then scale=.5;pcall(m.setTextScale,scale);local ok2,w2,h2=pcall(m.getSize);if ok2 then w,h=tonumber(w2)or w,tonumber(h2)or h end end;out[#out+1]={name=n,mon=m,w=w,h=h,scale=scale,area=w*h}end end end end;table.sort(out,function(a,b)if a.area~=b.area then return a.area>b.area end;if a.w~=b.w then return a.w>b.w end;return a.name<b.name end);return out end
local function put(e,x,y,text,fg)if y<1 or y>e.h or x>e.w then return end;x=math.max(1,x);text=tostring(text or"");e.mon.setCursorPos(x,y);e.mon.setTextColor(fg or C.text);e.mon.setBackgroundColor(C.bg);e.mon.write(text:sub(1,math.max(0,e.w-x+1)))end

function M.render(env,meta)
 local ok=base.render(env,meta);local mons=detectMonitors();local e=mons[2]
 if e and e.w<e.h*1.45 and e.h>=24 then
  local fx=(state(env).power or{}).fluxNetworks or{};local y=e.h-4
  put(e,2,y,"FLUX NETWORKS "..#fx,#fx>0 and C.good or C.warn)
  for i=1,math.min(#fx,2)do put(e,2,y+i,nice(fx[i].networkName or fx[i].peripheral or("NETWORK "..i)),C.text)end
 end
 return ok
end
function M.init(c)return base.init(c)end
function M.onPeripheralChange(...)if base.onPeripheralChange then return base.onPeripheralChange(...)end end
function M.handleEvent(...)if base.handleEvent then return base.handleEvent(...)end;return false end
return M
