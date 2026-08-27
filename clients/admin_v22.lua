-- Alpha73 compatibility overlay: keep rich Flux names on tall POWER monitors.
local base=require("clients.admin_v21")
local M={}
for k,v in pairs(base)do M[k]=v end

local function isMonitor(n)
 local ok,t=pcall(peripheral.getType,n);if ok and t=="monitor"then return true end
 if type(peripheral.hasType)=="function"then local ok2,v=pcall(peripheral.hasType,n,"monitor");if ok2 and v then return true end end
 return false
end
local function monitors()
 local out={};local ok,names=pcall(peripheral.getNames);if not ok or type(names)~="table"then return out end
 for _,n in ipairs(names)do if isMonitor(n)then
  local okw,m=pcall(peripheral.wrap,n);if okw and m then
   local scale=1;pcall(m.setTextScale,scale);local oks,w,h=pcall(m.getSize)
   if oks then
    w,h=tonumber(w),tonumber(h)
    if w<22 or h<12 then scale=.5;pcall(m.setTextScale,scale);local ok2,w2,h2=pcall(m.getSize);if ok2 then w,h=tonumber(w2)or w,tonumber(h2)or h end end
    out[#out+1]={name=n,mon=m,w=w,h=h,area=w*h}
   end
  end
 end end
 table.sort(out,function(a,b)if a.area~=b.area then return a.area>b.area end;if a.w~=b.w then return a.w>b.w end;return a.name<b.name end)
 return out
end
local function nice(v)return tostring(v or""):gsub("minecraft:",""):gsub("[_%-]"," "):upper()end

function M.render(env,meta)
 local ok=base.render(env,meta)
 local ms=monitors();local e=ms[2]
 if e and e.w<e.h*1.45 then
  local fx=env and env.state and env.state.power and env.state.power.fluxNetworks or{}
  local y=math.max(1,e.h-math.min(4,#fx+2)+1)
  e.mon.setBackgroundColor(colors.black);e.mon.setTextColor(colors.lightGray);e.mon.setCursorPos(2,y)
  e.mon.write(("FLUX NETWORKS "..tostring(#fx)):sub(1,math.max(0,e.w-2)))
  y=y+1
  for i,n in ipairs(fx)do if y>e.h then break end
   e.mon.setCursorPos(2,y);e.mon.setTextColor(colors.white)
   e.mon.write(nice(n.networkName or n.name or n.peripheral or("NETWORK "..i)):sub(1,math.max(0,e.w-2)))
   y=y+1
  end
 end
 return ok
end
return M
