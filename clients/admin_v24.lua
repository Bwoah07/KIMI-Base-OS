-- Alpha73 stable sensor-slot overlay. Preserve alpha72's one-sensor-per-screen
-- wall contract; only rotate when sensors outnumber the available sensor slots.
local base=require("clients.admin_v23")
local M={}
for k,v in pairs(base)do M[k]=v end
local C={bg=colors.black,text=colors.white,dim=colors.lightGray,good=colors.lime,panel=colors.gray}

local function nice(v)return tostring(v or""):gsub("minecraft:",""):gsub("[_%-]"," "):gsub("(%l)(%u)","%1 %2"):upper()end
local function hasCategory(d,w)for _,c in ipairs(d and d.categories or{})do if c==w then return true end end;return false end
local function sensors(env)
 local a=env and env.state and env.state.attachments or{};local out,seen={},{}
 for _,d in ipairs(a.sensors or{})do local k=tostring(d._source or"").."|"..tostring(d.name or d.type);if not seen[k]then seen[k]=true;out[#out+1]=d end end
 for _,d in ipairs(a.devices or{})do if hasCategory(d,"sensor")or hasCategory(d,"sensor_candidate")then local k=tostring(d._source or"").."|"..tostring(d.name or d.type);if not seen[k]then seen[k]=true;out[#out+1]=d end end end
 table.sort(out,function(a,b)return tostring(a.reportedName or a.name or a.type)<tostring(b.reportedName or b.name or b.type)end);return out
end
local function isMonitor(n)local ok,t=pcall(peripheral.getType,n);if ok and t=="monitor"then return true end;if type(peripheral.hasType)=="function"then local ok2,v=pcall(peripheral.hasType,n,"monitor");if ok2 and v then return true end end;return false end
local function monitors()
 local out={};local ok,names=pcall(peripheral.getNames);if not ok or type(names)~="table"then return out end
 for _,n in ipairs(names)do if isMonitor(n)then local okw,m=pcall(peripheral.wrap,n);if okw and m then local scale=1;pcall(m.setTextScale,scale);local oks,w,h=pcall(m.getSize);if oks then w,h=tonumber(w),tonumber(h);if w<22 or h<12 then scale=.5;pcall(m.setTextScale,scale);local ok2,w2,h2=pcall(m.getSize);if ok2 then w,h=tonumber(w2)or w,tonumber(h2)or h end end;out[#out+1]={name=n,mon=m,w=w,h=h,area=w*h,scale=scale}end end end end
 table.sort(out,function(a,b)if a.area~=b.area then return a.area>b.area end;if a.w~=b.w then return a.w>b.w end;return a.name<b.name end);return out
end
local function put(e,x,y,text,fg)if y<1 or y>e.h or x>e.w then return end;text=tostring(text or"");e.mon.setCursorPos(x,y);e.mon.setTextColor(fg or C.text);e.mon.setBackgroundColor(C.bg);e.mon.write(text:sub(1,math.max(0,e.w-x+1)))end
local function prep(e)pcall(e.mon.setTextScale,e.scale);e.mon.setBackgroundColor(C.bg);e.mon.setTextColor(C.text);e.mon.clear()end
local function rule(e,y)put(e,2,y,string.rep("-",math.max(0,e.w-2)),C.panel)end
local function renderSensor(e,s,index,total)
 prep(e);put(e,2,1,"SENSOR "..index.."/"..total,C.text);rule(e,3)
 if not s then put(e,2,6,"NO SENSOR",C.dim);return end
 put(e,2,5,nice(s.reportedName or s.name or s.type or("SENSOR "..index)),C.text)
 if s._source then put(e,2,6,"NODE "..tostring(s._source),C.dim)end
 put(e,2,8,nice(s.summary or"ONLINE"),C.good)
 local m=s.metrics or{};local rows={}
 local function add(k,v)if v~=nil then rows[#rows+1]={k,tostring(v)}end end
 add("TEMP",m.temperature);add("HUMIDITY",m.humidity);add("PRESSURE",m.pressure)
 if m.radiationRaw~=nil then add("RADIATION",m.radiationRaw)elseif m.radiationText~=nil then add("RADIATION",m.radiationText)end
 add("PLAYERS",m.onlinePlayers or m.playerCount);add("ENTITIES",m.entityCount);add("BLOCK LIGHT",m.blockLight);add("SKY LIGHT",m.skyLight)
 local y=10;for _,r in ipairs(rows)do if y+1>e.h then break end;put(e,2,y,r[1],C.dim);put(e,2,y+1,r[2],C.text);y=y+3 end
end
local function removeAt(t,i)local v=t[i];table.remove(t,i);return v end
local function sensorSlots(env)
 local ms=monitors();local extras={};for i=4,#ms do extras[#extras+1]=ms[i]end;if #extras==0 then return{}end
 local bi,bs=1,-1;for i,e in ipairs(extras)do local score=(e.w/math.max(1,e.h))*1000+e.area;if score>bs then bi,bs=i,score end end;removeAt(extras,bi) -- environment
 local st=env and env.state or{};local ae=st.ae2 or{};local builders=st.builder and st.builder.builders or{}
 if #extras>0 and(ae.bridge or ae.online==true or ae.connected==true)then removeAt(extras,1)end
 if #extras>0 and #builders>0 then removeAt(extras,1)end
 return extras
end

function M.render(env,meta)
 local ok=base.render(env,meta);local ss=sensors(env);local slots=sensorSlots(env)
 if #ss>0 and #slots>0 then
  local start=1
  if #ss>#slots then local pages=math.ceil(#ss/#slots);local now=type(os.epoch)=="function"and os.epoch("utc")or 0;local page=math.floor(now/8000)%pages;start=page*#slots+1 end
  for i,e in ipairs(slots)do local ix=start+i-1;if ix>#ss then ix=((ix-1)%#ss)+1 end;renderSensor(e,ss[ix],ix,#ss)end
 end
 return ok
end
return M
