local controller=require("core.power_reserve")
local M={id="power_reserve"}

local function methods(name)
 local ok,list=pcall(peripheral.getMethods,name);local set={}
 if ok and type(list)=="table"then for _,m in ipairs(list)do set[m]=true end end
 return set
end
local function call(name,method)
 local ok,v=pcall(peripheral.call,name,method);if ok then return v end
end
local function matrices()
 local out={}
 for _,name in ipairs(peripheral.getNames())do
  local m=methods(name)
  if m.getEnergy and m.getMaxEnergy and m.getLastInput and m.getLastOutput and m.getTransferCap then
   local stored=call(name,"getEnergy");local capacity=call(name,"getMaxEnergy")
   local input=call(name,"getLastInput");local output=call(name,"getLastOutput")
   local filled=call(name,"getEnergyFilledPercentage")
   if filled==nil and type(stored)=="number"and type(capacity)=="number"and capacity>0 then filled=stored/capacity end
   out[#out+1]={peripheral=name,stored=stored,capacity=capacity,input=input,output=output,filledPercentage=filled}
  end
 end
 return out
end
local function copy(v)local o={};for k,x in pairs(v or{})do o[k]=x end;return o end

function M.read()
 local ms=matrices();local state=controller.apply(ms)
 local main,reserve
 for _,m in ipairs(ms)do
  if m.reserveRole=="MAIN"then main=copy(m)elseif m.reserveRole=="RESERVE"then reserve=copy(m)end
 end
 state.main=main;state.reserve=reserve;state.matrixCount=#ms
 state._status=state.status=="GATE ERROR"and"error"or"online"
 state._updated=os.epoch("utc")
 return state
end

return M
