local base=require("clients.admin_v12")
local M={}
local cfg={}

local C={bg=colors.black,text=colors.white,dim=colors.lightGray,shell=colors.gray,good=colors.lime,warn=colors.orange,bad=colors.red}

local function upper(v)return tostring(v or""):upper()end
local function gameTime()local ok,t=pcall(os.time,"ingame");t=ok and tonumber(t)or 0;local h=math.floor(t%24);local m=math.floor(((t%24)-h)*60+.5)%60;return string.format("%02d:%02d",h,m)end
local function baseName()local l=type(os.getComputerLabel)=="function"and os.getComputerLabel()or nil;if l and tostring(l):match("%S")and not tostring(l):match("^KIMI[%s%-]?%d+$")then return upper(l)end;return upper(cfg.name or"MAIN BASE")end
local function state(env)return env and env.state or{}end
local function fmtNumber(v)local n=tonumber(v);if not n then return"?"end;local a=math.abs(n);if a>=1e12 then return string.format("%.1fT",n/1e12)elseif a>=1e9 then return string.format("%.1fG",n/1e9)elseif a>=1e6 then return string.format("%.1fM",n/1e6)elseif a>=1e3 then return string.format("%.1fK",n/1e3)end;return tostring(math.floor(n+.5))end
local function fmtFE(v,rate)local s=fmtNumber(v);return s=="?"and"?"or s.." FE"..(rate and"/t"or"")end
local function choosePower(raw)raw=raw or{};local best,score=raw,-1;local function use(p)if type(p)~="table"then return end;local cap=tonumber(p.capacity)or 0;local st=tonumber(p.stored)or 0;local s=(cap>0 and 1e9 or 0)+(st>0 and 1e7 or 0)+math.abs(tonumber(p.input)or 0)+math.abs(tonumber(p.output)or 0);if s>score then best,score=p,s end end;use(raw);for _,p in ipairs(raw.matrices or{})do use(p)end;for _,p in ipairs(raw.fluxNetworks or{})do use(p)end;return best or raw end
local function pct(p)local n=tonumber(p and p.filledPercentage);if n then if n<=1 then n=n*100 end;return math.max(0,math.min(100,n))end;local st,cap=tonumber(p and p.stored),tonumber(p and p.capacity);if st and cap and cap>0 then return math.max(0,math.min(100,st/cap*100))end end
local function chargeColor(pp)if not pp then return C.shell end;if pp<25 then return C.bad elseif pp<60 then return C.warn end;return C.good end

local function isMonitor(n)local ok,t=pcall(peripheral.getType,n);if ok and t=="monitor"then return true end;if type(peripheral.hasType)=="function"then local ok2,v=pcall(peripheral.hasType,n,"monitor");if ok2 and v then return true end end;return false end
local function detectMonitors()local out={};local ok,names=pcall(peripheral.getNames);if not ok or type(names)~="table"then return out end;for _,n in ipairs(names)do if isMonitor(n)then local okW,m=pcall(peripheral.wrap,n);if okW and m then local scale=1;pcall(m.setTextScale,scale);local okS,w,h=pcall(m.getSize);if okS then w,h=tonumber(w),tonumber(h);if w<22 or h<12 then scale=.5;pcall(m.setTextScale,scale);local ok2,w2,h2=pcall(m.getSize);if ok2 then w,h=tonumber(w2)or w,tonumber(h2)or h end end;out[#out+1]={name=n,mon=m,w=w,h=h,scale=scale,area=w*h}end end end end;table.sort(out,function(a,b)if a.area~=b.area then return a.area>b.area end;if a.w~=b.w then return a.w>b.w end;return a.name<b.name end);return out end
local function put(e,x,y,text,fg,bg)if y<1 or y>e.h or x>e.w then return end;x=math.max(1,x);text=tostring(text or"");e.mon.setCursorPos(x,y);e.mon.setTextColor(fg or C.text);e.mon.setBackgroundColor(bg or C.bg);e.mon.write(text:sub(1,math.max(0,e.w-x+1)));e.mon.setBackgroundColor(C.bg)end
local function fill(e,x1,y1,x2,y2,bg)x1,x2=math.max(1,x1),math.min(e.w,x2);y1,y2=math.max(1,y1),math.min(e.h,y2);if x2<x1 or y2<y1 then return end;for y=y1,y2 do put(e,x1,y,string.rep(" ",x2-x1+1),C.text,bg)end end
local function center(e,y,text,fg,bg,x1,x2)x1,x2=x1 or 1,x2 or e.w;local w=x2-x1+1;text=tostring(text or"");if #text>w then text=text:sub(1,w)end;put(e,x1+math.max(0,math.floor((w-#text)/2)),y,text,fg,bg)end
local function rule(e,y)if y>=1 and y<=e.h then put(e,2,y,string.rep("-",math.max(0,e.w-2)),C.shell)end end

local function redrawPower(e,env)
 local mon=e.mon;pcall(mon.setTextScale,e.scale);mon.setBackgroundColor(C.bg);mon.setTextColor(C.text);mon.clear()
 put(e,2,1,"POWER",C.text);put(e,math.max(2,e.w-6),1,gameTime(),C.dim);put(e,2,2,baseName(),C.dim);rule(e,3)
 local p=choosePower(state(env).power or{});local pp=pct(p);local color=chargeColor(pp)
 local bodyW=math.min(15,math.max(11,e.w-6));local x1=math.floor((e.w-bodyW)/2)+1;local x2=x1+bodyW-1
 local top=7;local bottom=math.min(e.h-8,22);if bottom-top<10 then bottom=math.min(e.h-5,top+10)end
 local capW=math.max(5,math.floor(bodyW*.45));local capX=x1+math.floor((bodyW-capW)/2)
 fill(e,capX,top-2,capX+capW-1,top-1,C.shell)
 fill(e,x1,top,x2,top,C.shell);fill(e,x1,bottom,x2,bottom,C.shell)
 fill(e,x1,top+1,x1+1,bottom-1,C.shell);fill(e,x2-1,top+1,x2,bottom-1,C.shell)
 local ix1,ix2=x1+3,x2-3;local iy1,iy2=top+1,bottom-1
 fill(e,ix1,iy1,ix2,iy2,C.bg)
 local innerH=math.max(1,iy2-iy1+1);local filledRows=pp and math.floor(innerH*(pp/100)+.5)or 0
 if pp and pp>0 and filledRows<1 then filledRows=1 end
 local fillTop=iy2-filledRows+1;if filledRows>0 then fill(e,ix1,fillTop,ix2,iy2,color)end
 local mid=math.floor((iy1+iy2)/2);local label=pp and string.format("%.0f%%",pp)or"?"
 local labelOnFill=filledRows>0 and mid>=fillTop;center(e,mid,label,labelOnFill and colors.black or C.text,labelOnFill and color or C.bg,ix1,ix2)
 -- tiny quarter-level tick marks on the shell make the gauge readable without chopping the fill into shelves.
 for _,f in ipairs({.25,.5,.75})do local ty=iy2-math.floor((innerH-1)*f);fill(e,x1-1,ty,x1,ty,C.dim);fill(e,x2,ty,x2+1,ty,C.dim)end
 local y=bottom+2;if y<=e.h then center(e,y,fmtFE(p.stored,false),C.text,nil,2,e.w-1)end
 if y+2<=e.h then put(e,2,y+2,"IN  +"..fmtFE(p.input,true),C.good)end
 if y+3<=e.h then put(e,2,y+3,"OUT -"..fmtFE(p.output,true),C.warn)end
end

function M.init(c)cfg=c or{};return base.init(c)end
function M.render(env,meta)
 local ok=base.render(env,meta)
 local mons=detectMonitors();if mons[2]then redrawPower(mons[2],env)end
 return ok
end
function M.onPeripheralChange(...)if base.onPeripheralChange then return base.onPeripheralChange(...)end end
function M.handleEvent(...)if base.handleEvent then return base.handleEvent(...)end;return false end
return M
