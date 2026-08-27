local reserve=require("core.power_reserve")

local function line()print(string.rep("-",38))end
local function methods(name)
 local ok,m=pcall(peripheral.getMethods,name);if not ok or type(m)~="table"then return{}end
 local set={};for _,v in ipairs(m)do set[v]=true end;return set
end
local function candidates()
 local out={{target="computer",label="THIS COMPUTER REDSTONE"}}
 for _,name in ipairs(peripheral.getNames())do
  local m=methods(name)
  if m.setOutput then out[#out+1]={target=name,label=name.."  [setOutput]"}end
 end
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

local args={...}
if args[1]=="off"then reserve.disable();print("KIMI reserve automation DISABLED");return end
if args[1]=="on"then reserve.enable();print("KIMI reserve automation ENABLED");return end
if args[1]=="status"then
 local c=reserve.load();print(textutils.serialize(c));return
end

term.clear();term.setCursorPos(1,1)
print("KIMI RESERVE MATRIX SETUP")
line()
print("Wire the BACKUP Matrix into the MAIN Matrix")
print("through a one-way power path controlled by")
print("a redstone gate/integrator.")
print("")
print("KIMI will FEED below the low threshold and")
print("stand down again above the high threshold.")
line()

local list=candidates()
print("CONTROL OUTPUT")
for i,c in ipairs(list)do print(string.format(" %d) %s",i,c.label))end
local idx=tonumber(ask("Choose gate",1))or 1;if not list[idx]then error("invalid gate selection",0)end
local target=list[idx].target
local sides={"top","bottom","left","right","front","back"}
print("")
for i,s in ipairs(sides)do print(string.format(" %d) %s",i,s))end
local si=tonumber(ask("Output side",1))or 1;if not sides[si]then error("invalid side",0)end
local inverted=ask("Gate active LOW? y/N","N"):lower():sub(1,1)=="y"
local low=percent(ask("Feed reserve below %",20),.20)
local high=percent(ask("Stop reserve above %",80),.80)
if high<=low then error("high threshold must be above low threshold",0)end

local cfg=reserve.load();cfg.enabled=true;cfg.low=low;cfg.high=high;cfg.gate={target=target,side=sides[si],inverted=inverted}
reserve.save(cfg)
line()
print("BSH RESERVE ARMED")
print("Gate: "..target.." / "..sides[si]..(inverted and" / ACTIVE LOW"or""))
print(string.format("Feed <= %.0f%%   Stand down >= %.0f%%",low*100,high*100))
print("")
print("KIMI will identify the two largest Matrix")
print("capacities as MAIN and RESERVE automatically.")
print("")
print("BRAAAAAAP.")
