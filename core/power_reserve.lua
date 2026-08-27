local M={}
local ROOT=".kimi"
local PATH=ROOT.."/power_reserve"
local runtime={feeding=nil,lastError=nil}

local defaults={enabled=true,low=0.20,high=0.80,gate=nil,mainPeripheral=nil,reservePeripheral=nil}

local function clone(v)
 if type(v)~="table" then return v end
 local out={};for k,x in pairs(v)do out[k]=clone(x)end;return out
end
local function merge(dst,src)
 for k,v in pairs(src or{})do if type(v)=="table"and type(dst[k])=="table"then merge(dst[k],v)else dst[k]=clone(v)end end
 return dst
end
local function clamp(v,a,b)v=tonumber(v)or a;if v<a then return a elseif v>b then return b end;return v end
local function pct(p)
 local n=tonumber(p and p.filledPercentage)
 if n then if n>1 then n=n/100 end;return clamp(n,0,1)end
 local st,cap=tonumber(p and p.stored),tonumber(p and p.capacity)
 if st and cap and cap>0 then return clamp(st/cap,0,1)end
end
local function present(name)
 if name=="computer"then return type(redstone)=="table"and type(redstone.setOutput)=="function"end
 if type(peripheral)~="table"then return false end
 if type(peripheral.isPresent)=="function"then local ok,v=pcall(peripheral.isPresent,name);if ok then return v==true end end
 if type(peripheral.getType)=="function"then local ok,v=pcall(peripheral.getType,name);return ok and v~=nil end
 return false
end

function M.load()
 local cfg=clone(defaults)
 if type(fs)=="table"and fs.exists(PATH)and not fs.isDir(PATH)then
  local f=fs.open(PATH,"r");local raw=f and f.readAll()or nil;if f then f.close()end
  local parsed=raw and textutils.unserialize(raw)or nil;if type(parsed)=="table"then merge(cfg,parsed)end
 end
 cfg.low=clamp(cfg.low,0.01,0.95);cfg.high=clamp(cfg.high,cfg.low+0.01,0.99)
 return cfg
end
function M.save(cfg)
 if not fs.exists(ROOT)then fs.makeDir(ROOT)end
 local out=merge(clone(defaults),cfg or{});out.low=clamp(out.low,0.01,0.95);out.high=clamp(out.high,out.low+0.01,0.99)
 local f=assert(fs.open(PATH,"w"));f.write(textutils.serialize(out));f.close();return out
end
function M.path()return PATH end

local function getGate(cfg)
 local g=type(cfg.gate)=="table"and cfg.gate or nil
 if not g or not g.target or not g.side then return nil,"reserve gate not configured"end
 if not present(g.target)then return nil,"reserve gate offline"end
 return g
end
local function readGate(g)
 if not g then return nil end
 local physical
 if g.target=="computer"and type(redstone.getOutput)=="function"then local ok,v=pcall(redstone.getOutput,g.side);if ok then physical=v==true end
 elseif type(peripheral.call)=="function"then local ok,v=pcall(peripheral.call,g.target,"getOutput",g.side);if ok then physical=v==true end end
 if physical==nil then return nil end
 return g.inverted==true and not physical or physical
end
local function setGate(g,feeding)
 local physical=feeding==true;if g.inverted==true then physical=not physical end
 if g.target=="computer"then
  if type(redstone)~="table"or type(redstone.setOutput)~="function"then return false,"computer redstone unavailable"end
  local ok,err=pcall(redstone.setOutput,g.side,physical);return ok,ok and nil or tostring(err)
 end
 if type(peripheral)~="table"or type(peripheral.call)~="function"then return false,"peripheral.call unavailable"end
 local ok,err=pcall(peripheral.call,g.target,"setOutput",g.side,physical);return ok,ok and nil or tostring(err)
end

local function sortedMatrices(matrices,cfg)
 local out={};for _,m in ipairs(matrices or{})do if type(m)=="table"then out[#out+1]=m end end
 table.sort(out,function(a,b)
  local ap,bp=tostring(a.peripheral or""),tostring(b.peripheral or"")
  if cfg and cfg.mainPeripheral then
   if ap==tostring(cfg.mainPeripheral)and bp~=tostring(cfg.mainPeripheral)then return true end
   if bp==tostring(cfg.mainPeripheral)and ap~=tostring(cfg.mainPeripheral)then return false end
  end
  if cfg and cfg.reservePeripheral then
   if ap==tostring(cfg.reservePeripheral)and bp~=tostring(cfg.reservePeripheral)then return false end
   if bp==tostring(cfg.reservePeripheral)and ap~=tostring(cfg.reservePeripheral)then return true end
  end
  local ac,bc=tonumber(a.capacity)or 0,tonumber(b.capacity)or 0
  if ac~=bc then return ac>bc end
  return ap<bp
 end)
 return out
end

function M.apply(matrices)
 local cfg=M.load();local sorted=sortedMatrices(matrices,cfg)
 local main,reserve=sorted[1],sorted[2]
 if cfg.mainPeripheral then for _,m in ipairs(sorted)do if tostring(m.peripheral)==tostring(cfg.mainPeripheral)then main=m;break end end end
 if cfg.reservePeripheral then for _,m in ipairs(sorted)do if tostring(m.peripheral)==tostring(cfg.reservePeripheral)then reserve=m;break end end end
 if main and reserve and main==reserve then reserve=nil end
 for _,m in ipairs(matrices or{})do m.reserveRole=nil end
 if main then main.reserveRole="MAIN"end;if reserve then reserve.reserveRole="RESERVE"end
 local mp,rp=pct(main),pct(reserve)
 local out={
  enabled=cfg.enabled~=false,configured=false,feeding=false,status="NO RESERVE MATRIX",
  low=cfg.low,high=cfg.high,lowPercent=cfg.low*100,highPercent=cfg.high*100,
  mainPeripheral=main and main.peripheral or nil,reservePeripheral=reserve and reserve.peripheral or nil,
  mainPercent=mp and mp*100 or nil,reservePercent=rp and rp*100 or nil,
  gate=cfg.gate,
 }
 if not main then out.status="NO MAIN MATRIX";runtime.feeding=false;return out end
 if not reserve then runtime.feeding=false;return out end
 if cfg.enabled==false then
  local g=getGate(cfg);if g then pcall(setGate,g,false)end
  runtime.feeding=false;out.status="RESERVE DISABLED";return out
 end
 local gate,gerr=getGate(cfg)
 if not gate then out.status=tostring(gerr):upper();runtime.lastError=gerr;return out end
 out.configured=true
 local current=readGate(gate);if current==nil then current=runtime.feeding==true end
 local desired=current
 if not rp or rp<=0.001 then desired=false;out.status="RESERVE EMPTY"
 elseif mp and mp<=cfg.low then desired=true
 elseif mp and mp>=cfg.high then desired=false
 end
 local ok,err=setGate(gate,desired)
 if not ok then out.status="GATE ERROR";out.error=err;runtime.lastError=err;runtime.feeding=current;out.feeding=current;return out end
 runtime.feeding=desired;runtime.lastError=nil;out.feeding=desired
 if desired then out.status="FEEDING MAIN"
 elseif rp and rp>=0.999 then out.status="RESERVE FULL"
 else out.status="RESERVE ARMED"end
 return out
end

function M.disable()
 local cfg=M.load();cfg.enabled=false;M.save(cfg);local g=getGate(cfg);if g then pcall(setGate,g,false)end;runtime.feeding=false;return cfg
end
function M.enable()local cfg=M.load();cfg.enabled=true;return M.save(cfg)end

return M
