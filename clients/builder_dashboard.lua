local M={}
local health=require("core.fleet_health")

local C={bg=colors.black,text=colors.white,dim=colors.lightGray,good=colors.lime,warn=colors.orange,bad=colors.red,panel=colors.gray,accent=colors.cyan or colors.lightBlue,button=colors.blue}
local cfg={}
local lastEnv,lastMeta
local pages={}
local targets={}

local function upper(v)return tostring(v or""):upper()end
local function nice(v)return upper(tostring(v or""):gsub("minecraft:",""):gsub("[_%-]"," "):gsub("(%l)(%u)","%1 %2"))end
local function now()local ok,v=pcall(os.epoch,"utc");return ok and tonumber(v)or 0 end
local function gameTime()local ok,t=pcall(os.time,"ingame");t=ok and tonumber(t)or 0;local h=math.floor(t%24);local m=math.floor(((t%24)-h)*60+.5)%60;return string.format("%02d:%02d",h,m)end
local function fmt(n)local v=tonumber(n);if not v then return"?"end;local a=math.abs(v);if a>=1e12 then return string.format("%.1fT",v/1e12)elseif a>=1e9 then return string.format("%.1fG",v/1e9)elseif a>=1e6 then return string.format("%.1fM",v/1e6)elseif a>=1e3 then return string.format("%.1fK",v/1e3)end;return tostring(math.floor(v+.5))end
local function duration(s)s=tonumber(s);if not s then return"--"end;s=math.floor(s+.5);if s<60 then return tostring(s).."s"end;if s<3600 then return string.format("%dm %02ds",math.floor(s/60),s%60)end;return string.format("%dh %02dm",math.floor(s/3600),math.floor((s%3600)/60))end

local function isMonitor(name)local ok,t=pcall(peripheral.getType,name);if ok and t=="monitor"then return true end;if type(peripheral.hasType)=="function"then local ok2,v=pcall(peripheral.hasType,name,"monitor");if ok2 and v then return true end end;return false end
local function monitors()
 local out={};local ok,names=pcall(peripheral.getNames);if not ok or type(names)~="table"then return out end
 for _,name in ipairs(names)do if isMonitor(name)then local okw,mon=pcall(peripheral.wrap,name);if okw and mon then local scale=1;pcall(mon.setTextScale,scale);local oks,w,h=pcall(mon.getSize);if oks then w,h=tonumber(w),tonumber(h);if w<22 or h<12 then scale=.5;pcall(mon.setTextScale,scale);local ok2,w2,h2=pcall(mon.getSize);if ok2 then w,h=tonumber(w2)or w,tonumber(h2)or h end end;out[#out+1]={name=name,mon=mon,w=w,h=h,area=w*h,scale=scale}end end end end
 table.sort(out,function(a,b)if a.area~=b.area then return a.area>b.area end;if a.w~=b.w then return a.w>b.w end;return a.name<b.name end);return out
end
local function put(e,x,y,text,fg,bg)if not e or y<1 or y>e.h or x>e.w then return end;x=math.max(1,x);text=tostring(text or"");pcall(e.mon.setCursorPos,x,y);pcall(e.mon.setBackgroundColor,bg or C.bg);pcall(e.mon.setTextColor,fg or C.text);pcall(e.mon.write,text:sub(1,math.max(0,e.w-x+1)))end
local function fill(e,x1,y1,x2,y2,bg)x1,x2=math.max(1,x1),math.min(e.w,x2);y1,y2=math.max(1,y1),math.min(e.h,y2);if x2<x1 or y2<y1 then return end;for y=y1,y2 do put(e,x1,y,string.rep(" ",x2-x1+1),C.text,bg)end end
local function center(e,y,text,fg,bg,x1,x2)x1,x2=x1 or 1,x2 or e.w;local width=math.max(1,x2-x1+1);text=tostring(text or"");if #text>width then text=text:sub(1,width)end;put(e,x1+math.max(0,math.floor((width-#text)/2)),y,text,fg,bg)end
local function rule(e,y)put(e,2,y,string.rep("-",math.max(0,e.w-2)),C.panel)end
local function bar(e,x1,y,x2,p,color)fill(e,x1,y,x2,y,C.panel);p=math.max(0,math.min(100,tonumber(p)or 0));local n=math.floor((x2-x1+1)*p/100+.5);if n>0 then fill(e,x1,y,x1+n-1,y,color or C.good)end end
local function statusColor(b)local s=upper(b and(b.issue or b.status));if s:find("ERROR",1,true)or s:find("NO POWER",1,true)then return C.bad end;if s:find("STALL",1,true)or s:find("CACHED",1,true)then return C.warn end;return C.good end

function M.paint(e,b,index,total,opts)
 opts=opts or{};targets[e.name]={};pcall(e.mon.setTextScale,e.scale or 1);pcall(e.mon.setBackgroundColor,C.bg);pcall(e.mon.setTextColor,C.text);pcall(e.mon.clear)
 put(e,2,1,upper(opts.title or"BUILDER CONTROL"),C.text);put(e,math.max(2,e.w-6),1,gameTime(),C.dim);rule(e,2)
 if not b then center(e,6,"NO BUILDER TELEMETRY",C.warn,nil,2,e.w-1);center(e,8,"ATTACH BUILDER OR BLOCK READER",C.dim,nil,2,e.w-1);center(e,9,"FACE READER TOWARD THE BUILDER",C.dim,nil,2,e.w-1);return end
 local status=upper(b.issue or b.status or(b.running==true and"RUNNING"or"CONNECTED"));local data=upper(b._telemetryStatus or opts.telemetryStatus or"LIVE")
 put(e,2,3,nice(b.targetBlock or b.type or b.peripheral or"BUILDER"),C.text);put(e,math.max(2,e.w-#tostring(index.."/"..total)-1),3,index.."/"..total,C.dim)
 put(e,2,4,status,statusColor(b));put(e,math.max(2,e.w-#data-1),4,data,data=="CACHED"and C.warn or C.good)
 if b._source then put(e,2,5,"NODE "..tostring(b._source)..(b._connected==false and"  NOT REACHABLE"or""),b._connected==false and C.warn or C.dim)elseif b.peripheral then put(e,2,5,"PORT "..tostring(b.peripheral),C.dim)end
 local p=tonumber(b.progress);local y=7
 if p then
  put(e,2,y,string.format("PROGRESS %.1f%%",p),C.text);bar(e,2,y+1,e.w-2,p,b.stalled and C.warn or C.good);y=y+3
  if b.progressApprox or b.progressSource then put(e,2,y,b.progressApprox and"ESTIMATED FROM SCAN POSITION"or tostring(b.progressSource),C.dim);y=y+2 end
 else put(e,2,y,b.apiLimited and"PROGRESS API NOT EXPOSED"or"WAITING FOR FIRST SAMPLE",C.warn);y=y+2 end
 local wide=e.w>=46
 if wide then
  local mid=math.floor(e.w/2)+1
  put(e,2,y,"WORK",C.dim);put(e,mid,y,"POWER / POSITION",C.dim);y=y+1
  if b.processed or b.total then put(e,2,y,"DONE "..fmt(b.processed).." / "..fmt(b.total),C.text)else put(e,2,y,"MODE "..nice(b.mode or b.card or"UNKNOWN"),C.text)end
  if b.energy~=nil then put(e,mid,y,"ENERGY "..fmt(b.energy).." / "..fmt(b.energyCapacity),C.text)elseif b.position then put(e,mid,y,"XYZ "..b.position,C.text)end;y=y+1
  if b.remaining then put(e,2,y,"REMAIN "..fmt(b.remaining),C.dim)elseif b.volume then put(e,2,y,"VOLUME "..fmt(b.volume),C.dim)end
  if b.energyPercent then put(e,mid,y,string.format("CHARGE %.1f%%",b.energyPercent),b.energyPercent<10 and C.bad or C.good)elseif b.position then put(e,mid,y,"XYZ "..b.position,C.dim)end;y=y+1
  if b.rate then put(e,2,y,string.format("RATE %.2f blocks/s",b.rate),C.good)else put(e,2,y,"RATE --",C.dim)end
  if b.sizeX then put(e,mid,y,"BOX "..b.sizeX.."x"..b.sizeY.."x"..b.sizeZ,C.dim)elseif b.currentY then put(e,mid,y,"CURRENT Y "..b.currentY,C.dim)end;y=y+1
  put(e,2,y,"ETA "..duration(b.etaSeconds),b.etaSeconds and C.good or C.dim);if b.energyUsage then put(e,mid,y,"USE "..fmt(b.energyUsage).." FE/t",C.dim)end;y=y+2
 else
  local rows={{"DONE",(b.processed or b.total)and(fmt(b.processed).." / "..fmt(b.total))},{"REMAIN",b.remaining and fmt(b.remaining)},{"RATE",b.rate and string.format("%.2f/s",b.rate)},{"ETA",b.etaSeconds and duration(b.etaSeconds)},{"XYZ",b.position or b.currentY},{"BOX",b.sizeX and(b.sizeX.."x"..b.sizeY.."x"..b.sizeZ)},{"ENERGY",b.energy and(fmt(b.energy).." / "..fmt(b.energyCapacity))}}
  for _,row in ipairs(rows)do if row[2]~=nil and y<=e.h-2 then put(e,2,y,row[1].." "..tostring(row[2]),row[1]=="RATE"and C.good or C.dim);y=y+1 end end
 end
 if b.error and y<=e.h-2 then put(e,2,y,"ERROR "..tostring(b.error),C.bad);y=y+1 end
 if b.stalled and y<=e.h-2 then put(e,2,y,"NO MOVEMENT FOR "..duration(b.stalledSeconds),C.warn);y=y+1 end
 if b.apiLimited and type(b.rawFields)=="table"and y<=e.h-2 then
  put(e,2,y,"RAW BUILDER DATA ("..tostring(b.rawFieldCount or#b.rawFields).." FIELDS)",C.dim);y=y+1
  for _,r in ipairs(b.rawFields)do if y>e.h-2 then break end;put(e,2,y,nice(r.path).." = "..tostring(r.value),C.text);y=y+1 end
 end
 if total>1 and e.h>=2 then
  local label="< PREV     NEXT >";center(e,e.h,label,C.text,C.button,2,e.w-1);targets[e.name]={{x1=2,x2=math.floor(e.w/2),y=e.h,delta=-1},{x1=math.floor(e.w/2)+1,x2=e.w-1,y=e.h,delta=1}}
 elseif e.h>=2 then put(e,2,e.h,"UPDATED "..health.ageText(tonumber(b._telemetryAgeMs)or 0).." AGO",C.dim)end
end

local function localBuilders(meta)local s=meta and meta.localState or{};local b=s.builder or{};return b.builders or{}end
function M.init(c)cfg=c or{};pages={};targets={};lastEnv,lastMeta=nil,nil end
function M.render(env,meta)
 lastEnv,lastMeta=env,meta;local list=localBuilders(meta);local ms=monitors()
 for i,e in ipairs(ms)do local page=pages[e.name]or(((i-1)%math.max(1,#list))+1);page=math.max(1,math.min(math.max(1,#list),page));pages[e.name]=page;M.paint(e,list[page],page,#list,{title=cfg.name or"BUILDER NODE",telemetryStatus="LIVE"})end
 return true
end
function M.onState(state)lastEnv=state end
function M.onPeripheralChange()if lastEnv or lastMeta then return M.render(lastEnv,lastMeta)end end
function M.handleEvent(ev,env)
 if ev[1]~="monitor_touch"then return false end;local name,x,y=ev[2],tonumber(ev[3]),tonumber(ev[4]);local list=localBuilders(lastMeta)
 for _,t in ipairs(targets[name]or{})do if x and y==t.y and x>=t.x1 and x<=t.x2 and#list>1 then pages[name]=((pages[name]or 1)-1+t.delta)%#list+1;M.render(env or lastEnv,lastMeta);return true end end
 return false
end

return M
