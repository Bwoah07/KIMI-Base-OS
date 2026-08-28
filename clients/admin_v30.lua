-- Alpha81 semantic polish: when the main Matrix is genuinely live and the
-- reserve controller reports exactly one Matrix, show NOT INSTALLED for the
-- absent backup. Offline main telemetry remains WAITING FOR LIVE MAIN from v29.
local base=require("clients.admin_v29")
local M={}
for k,v in pairs(base)do M[k]=v end

local function isMonitor(n)
 local ok,t=pcall(peripheral.getType,n);if ok and t=="monitor"then return true end
 if type(peripheral.hasType)=="function"then local ok2,v=pcall(peripheral.hasType,n,"monitor");if ok2 and v then return true end end
 return false
end
local function monitors()
 local out={};local ok,names=pcall(peripheral.getNames);if not ok or type(names)~="table"then return out end
 for _,n in ipairs(names)do if isMonitor(n)then local okw,m=pcall(peripheral.wrap,n);if okw and m then local scale=1;pcall(m.setTextScale,scale);local oks,w,h=pcall(m.getSize);if oks then w,h=tonumber(w),tonumber(h);if w<22 or h<12 then scale=.5;pcall(m.setTextScale,scale);local ok2,w2,h2=pcall(m.getSize);if ok2 then w,h=tonumber(w2)or w,tonumber(h2)or h end end;out[#out+1]={name=n,mon=m,w=w,h=h,area=w*h,scale=scale}end end end end
 table.sort(out,function(a,b)if a.area~=b.area then return a.area>b.area end;if a.w~=b.w then return a.w>b.w end;return a.name<b.name end);return out
end

function M.render(env,meta)
 local ok=base.render(env,meta)
 local ms=monitors();local e=ms[2];local st=env and env.state or{};local p=st.power or{};local rs=st.power_reserve or{}
 if e and e.w>=e.h*1.45 and #(p.matrices or{})==1 and tostring(rs.status or""):upper()=="NO RESERVE MATRIX"then
  local col=math.max(12,math.floor((e.w-6)/3));local a1=2;local a2=math.min(e.w-2,a1+col-1);local b1=a2+2;local b2=math.min(e.w-2,b1+col-1)
  e.mon.setBackgroundColor(colors.black);e.mon.setTextColor(colors.black);e.mon.setCursorPos(b1,6);e.mon.write(string.rep(" ",math.max(0,b2-b1+1)))
  e.mon.setCursorPos(b1,6);e.mon.setTextColor(colors.lightGray);e.mon.write("NOT INSTALLED")
 end
 return ok
end
return M
