local reserve=require("core.power_reserve")

local function line()print(string.rep("-",38))end
local function methods(name)
 local ok,m=pcall(peripheral.getMethods,name);if not ok or type(m)~="table"then return{}end
 local set={};for _,v in ipairs(m)do set[v]=true end;return set
end
local function gates()
 local out={{target="computer",label="THIS COMPUTER REDSTONE"}}
 for _,name in ipairs(peripheral.getNames())do local m=methods(name);if m.setOutput then out[#out+1]={target=name,label=name.."  [setOutput]"}end end
 return out
end
local function matrices()
 local out={}
 for _,name in ipairs(peripheral.getNames())do
  local m=methods(name)
  if m.getEnergy and m.getMaxEnergy and m.getLastInput and m.getLastOutput and m.getTransferCap then
   local ok,cap=pcall(peripheral.call,name,"getMaxEnergy");out[#out+1]={name=name,capacity=ok and tonumber(cap)or nil}
  end
 end
 table.sort(out,function(a,b)local ac,bc=a.capacity or 0,b.capacity or 0;if ac~=bc then return ac>bc end;return a.name<b.name end)
 return out
end
local function ask(prompt,default)
 write(prompt);if default~=nil then write(" ["..tostring(default).."]")end;write(": ")
 local v=read();if v==""and default~=nil then return tostring(default)end;return v
end
local function percent(v,default)
 local n=tonumber(v);if not n then return default end
 if n>1 then n=n/100 end;return math.max(.01,math.min(.99,n))
end
local function fmt(n)
 n=tonumber(n);if not n then return"?"end
 if n>=1e15 then return string.format("%.1fP",n/1e15)elseif n>=1e12 then return string.format("%.1fT",n/1e12)elseif n>=1e9 then return string.format("%.1fG",n/1e9)elseif n>=1e6 then return string.format("%.1fM",n/1e6)end
 return tostring(math.floor(n+.5))
end

local args={...}
if args[1]=="off"then reserve.disable();print("KIMI reserve automation DISABLED");return end
if args[1]=="on"then reserve.enable();print("KIMI reserve automation ENABLED");return end
if args[1]=="status"then local c=reserve.load();print(textutils.serialize(c));return end

term.clear();term.setCursorPos(1,1)
print("KIMI RESERVE MATRIX SETUP")
line()
print("Wire BACKUP -> MAIN through a one-way")
print("power path controlled by a redstone gate.")
print("")
print("KIMI feeds below the low threshold and")
print("stands down above the high threshold.")
line()

local ms=matrices()
if #ms<2 then error("KIMI needs two visible Induction Matrices before reserve setup",0)end
print("MATRICES")
for i,m in ipairs(ms)do print(string.format(" %d) %s  %s FE",i,m.name,fmt(m.capacity)))end
local mi=tonumber(ask("MAIN Matrix",1))or 1;if not ms[mi]then error("invalid MAIN Matrix",0)end
local ri=tonumber(ask("RESERVE Matrix",mi==1 and 2 or 1))or(mi==1 and 2 or 1);if not ms[ri]or ri==mi then error("RESERVE must be a different Matrix",0)end

line()
local list=gates()
print("CONTROL OUTPUT")
for i,c in ipairs(list)do print(string.format(" %d) %s",i,c.label))end
local idx=tonumber(ask("Choose gate",1))or 1;if not list[idx]then error("invalid gate selection",0)end
local target=list[idx].target
local sides={"top","bottom","left","right","front","back"}
for i,s in ipairs(sides)do print(string.format(" %d) %s",i,s))end
local si=tonumber(ask("Output side",1))or 1;if not sides[si]then error("invalid side",0)end
local inverted=ask("Gate active LOW? y/N","N"):lower():sub(1,1)=="y"
local low=percent(ask("Feed reserve below %",20),.20)
local high=percent(ask("Stop reserve above %",80),.80)
if high<=low then error("high threshold must be above low threshold",0)end

local cfg=reserve.load();cfg.enabled=true;cfg.low=low;cfg.high=high;cfg.mainPeripheral=ms[mi].name;cfg.reservePeripheral=ms[ri].name;cfg.gate={target=target,side=sides[si],inverted=inverted}
reserve.save(cfg)
line()
print("BSH RESERVE ARMED")
print("MAIN:    "..ms[mi].name)
print("RESERVE: "..ms[ri].name)
print("Gate:    "..target.." / "..sides[si]..(inverted and" / ACTIVE LOW"or""))
print(string.format("Feed <= %.0f%%   Stand down >= %.0f%%",low*100,high*100))
print("")
print("BRAAAAAAP.")
