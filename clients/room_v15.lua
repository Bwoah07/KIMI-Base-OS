local base = require("clients.room_v12")
local M = {}

local C = {bg=colors.black,text=colors.white,dim=colors.lightGray,good=colors.lime,warn=colors.orange,bad=colors.red,action=colors.blue,panel=colors.gray}
local FLAG = ".kimi/door_setup_request"
local lastEnv, lastMeta
local setupActive = false
local setupStage = "controller"
local selectedTarget = nil
local pending = nil
local setupTargets = {}

local function upper(v) return tostring(v or ""):upper() end
local function nice(v) return upper(tostring(v or ""):gsub("minecraft:",""):gsub("[_%-]"," "):gsub("(%l)(%u)","%1 %2")) end
local function localState(meta) return meta and meta.localState or {} end
local function localDoors(meta)
  local d = localState(meta).doors
  return d and d.localDoors or {}
end
local function allCandidates(meta)
  local d = localState(meta).doors
  return d and d.candidates or {}
end
local function requested()
  if type(fs)~="table" or type(fs.exists)~="function" then return false end
  local ok,exists=pcall(fs.exists,FLAG)
  if not ok or not exists then return false end
  if type(fs.isDir)~="function" then return true end
  local okDir,isDir=pcall(fs.isDir,FLAG)
  return not (okDir and isDir)
end
local function clearRequest()
  if requested() and type(fs)=="table" and type(fs.delete)=="function" then pcall(fs.delete, FLAG) end
end
local function isMonitor(name)
  local ok,t=pcall(peripheral.getType,name)
  if ok and t=="monitor" then return true end
  if ok and type(t)=="table" then for _,v in ipairs(t) do if v=="monitor" then return true end end end
  if type(peripheral.hasType)=="function" then local ok2,has=pcall(peripheral.hasType,name,"monitor"); if ok2 and has then return true end end
  return false
end
local function primary()
  local best
  local ok,names=pcall(peripheral.getNames)
  if not ok or type(names)~="table" then return nil end
  for _,name in ipairs(names) do
    if isMonitor(name) then
      local okW,mon=pcall(peripheral.wrap,name)
      if okW and mon then
        pcall(mon.setTextScale,1)
        local okS,w,h=pcall(mon.getSize)
        if okS and tonumber(w) and tonumber(h) then
          local e={name=name,mon=mon,w=tonumber(w),h=tonumber(h)}; e.area=e.w*e.h
          if not best or e.area>best.area or (e.area==best.area and e.w>best.w) then best=e end
        end
      end
    end
  end
  return best
end
local function put(e,x,y,text,fg,bg)
  if not e or y<1 or y>e.h then return end
  text=tostring(text or "")
  x=math.max(1,math.min(e.w,x))
  pcall(e.mon.setCursorPos,x,y); pcall(e.mon.setTextColor,fg or C.text); pcall(e.mon.setBackgroundColor,bg or C.bg); pcall(e.mon.write,text:sub(1,e.w-x+1))
end
local function fill(e,x1,y1,x2,y2,bg)
  x1,x2=math.max(1,x1),math.min(e.w,x2); y1,y2=math.max(1,y1),math.min(e.h,y2)
  for y=y1,y2 do put(e,x1,y,string.rep(" ",math.max(0,x2-x1+1)),C.text,bg) end
end
local function center(e,y,text,fg,bg,x1,x2)
  x1,x2=x1 or 1,x2 or e.w; local width=math.max(1,x2-x1+1); text=tostring(text or ""); if #text>width then text=text:sub(1,width) end
  put(e,x1+math.max(0,math.floor((width-#text)/2)),y,text,fg,bg)
end
local function rule(e,y) put(e,1,y,string.rep("-",e.w),C.panel) end
local function register(e,name,x1,y1,x2,y2,data)
  setupTargets[#setupTargets+1]={monitor=e.name,name=name,x1=x1,y1=y1,x2=x2,y2=y2,data=data}
end
local function button(e,name,x1,y1,x2,y2,label,data,bg)
  x1,x2=math.max(2,x1),math.min(e.w-1,x2); fill(e,x1,y1,x2,y2,bg or C.action); center(e,math.floor((y1+y2)/2),label,C.text,bg or C.action,x1+2,x2-2); register(e,name,x1,y1,x2,y2,data)
end

local function controllerGroups(meta)
  local groups,order={},{}
  for _,c in ipairs(allCandidates(meta)) do
    local k=tostring(c.target or "")
    if k~="" then
      if not groups[k] then groups[k]={}; order[#order+1]=k end
      groups[k][#groups[k]+1]=c
    end
  end
  table.sort(order,function(a,b)
    local ca,cb=groups[a][1] or {},groups[b][1] or {}
    local pa,pb=tonumber(ca.priority) or 9,tonumber(cb.priority) or 9
    if pa~=pb then return pa<pb end
    if a=="computer" and b~="computer" then return false end
    if b=="computer" and a~="computer" then return true end
    return a<b
  end)
  return order,groups
end

local function renderController(e,meta)
  local order,groups=controllerGroups(meta)
  center(e,5,"DOOR SETUP",C.text,nil,2,e.w-1)
  center(e,7,"1. CHOOSE CONTROLLER",C.dim,nil,2,e.w-1)
  if #order==0 then center(e,10,"NO REDSTONE ACTUATOR",C.warn,nil,2,e.w-1); return end
  local y=10
  for i,target in ipairs(order) do
    if i>4 then break end
    local c=groups[target][1] or {}
    local label=target=="computer" and "THIS COMPUTER" or nice(c.controller or c.type or target)
    button(e,"select_controller",3,y,e.w-2,y+1,label,{target=target},i==1 and C.action or C.panel)
    y=y+3
  end
end

local function renderSide(e,meta)
  local _,groups=controllerGroups(meta)
  local list=groups[tostring(selectedTarget or "")] or {}
  center(e,5,"DOOR SETUP",C.text,nil,2,e.w-1)
  center(e,7,"2. CHOOSE OUTPUT SIDE",C.dim,nil,2,e.w-1)
  if #list==0 then center(e,10,"CONTROLLER DISCONNECTED",C.bad,nil,2,e.w-1); return end
  local first=list[1]
  center(e,9,selectedTarget=="computer" and "THIS COMPUTER" or nice(first.controller or first.type or selectedTarget),C.good,nil,2,e.w-1)
  local sided={}
  for _,c in ipairs(list) do if c.side~=nil and tostring(c.side)~="" then sided[#sided+1]=c end end
  if #sided==0 then
    pending={target=first.target,side=nil,name="ROOM PANEL"}
    setupStage="mode"
    return renderSetup and renderSetup(meta) or nil
  end
  local left,right,gap=3,e.w-2,1; local cell=math.floor((right-left+1-gap*2)/3)
  for i,c in ipairs(sided) do
    if i>6 then break end
    local col,row=(i-1)%3,math.floor((i-1)/3); local x1=left+col*(cell+gap); local x2=col==2 and right or x1+cell-1; local y=11+row*3
    button(e,"select_side",x1,y,x2,y+1,nice(c.side),{target=c.target,side=c.side,name="ROOM PANEL"})
  end
  center(e,19,"TAP THE SIDE WIRED TO DOOR",C.dim,nil,2,e.w-1)
end

local function renderMode(e)
  center(e,5,"DOOR SETUP",C.text,nil,2,e.w-1)
  center(e,7,"3. REDSTONE LOGIC",C.dim,nil,2,e.w-1)
  if pending then center(e,9,nice((pending.target=="computer" and "THIS COMPUTER" or pending.target).." "..tostring(pending.side or "")),C.good,nil,2,e.w-1) end
  button(e,"select_mode",3,12,math.floor(e.w/2)-1,16,"NORMAL",{mode="hold"},C.good)
  button(e,"select_mode",math.floor(e.w/2)+1,12,e.w-2,16,"INVERTED",{mode="invert"},C.warn)
  center(e,18,"NORMAL: ON = OPEN",C.dim,nil,2,e.w-1)
  center(e,19,"INVERTED: OFF = OPEN",C.dim,nil,2,e.w-1)
end

function renderSetup(meta)
  local e=primary(); if not e then return false end
  setupTargets={}
  pcall(e.mon.setBackgroundColor,C.bg); pcall(e.mon.setTextColor,C.text); pcall(e.mon.clear)
  put(e,2,1,"ROOM PANEL",C.text); put(e,math.max(2,e.w-8),1,"SETUP",C.warn); rule(e,2)
  if setupStage=="side" and selectedTarget then renderSide(e,meta)
  elseif setupStage=="mode" and pending then renderMode(e)
  else renderController(e,meta) end
  return true
end

local function beginIfNeeded(meta)
  if requested() then setupActive=true end
  if #localDoors(meta)==0 then setupActive=true end
end
local function removeExisting(action)
  for _,d in ipairs(localDoors(lastMeta)) do
    local ok,res=action("__local_doors","remove_local",{_source=tostring(os.getComputerID()),target=d.target,side=d.side})
    if ok==false then return false,res end
  end
  return true
end
local function commitSetup(mode,action)
  if not pending then return false,"no output side selected" end
  local ok,res=removeExisting(action); if ok==false then return false,res end
  ok,res=action("__local_doors","register_local",{_source=tostring(os.getComputerID()),target=pending.target,side=pending.side,name=pending.name or "ROOM PANEL"})
  if ok==false then return false,res end
  if mode=="invert" then
    ok,res=action("__local_doors","configure_local",{_source=tostring(os.getComputerID()),target=pending.target,side=pending.side,mode="invert"})
    if ok==false then return false,res end
  end
  clearRequest(); setupActive=false; setupStage="controller"; selectedTarget=nil; pending=nil
  return true,res
end

function M.init(cfg)
  lastEnv,lastMeta=nil,nil; setupActive=requested(); setupStage="controller"; selectedTarget=nil; pending=nil; setupTargets={}
  if base.init then return base.init(cfg) end
end
function M.render(env,meta)
  lastEnv,lastMeta=env,meta; beginIfNeeded(meta)
  if setupActive then return renderSetup(meta) end
  return base.render and base.render(env,meta) or true
end
function M.onPeripheralChange(...)
  if setupActive and lastMeta then return renderSetup(lastMeta) end
  if base.onPeripheralChange then return base.onPeripheralChange(...) end
end
function M.handleEvent(ev,env,action)
  if setupActive and ev[1]=="monitor_touch" then
    local name,x,y=ev[2],tonumber(ev[3]),tonumber(ev[4])
    for _,t in ipairs(setupTargets) do
      if name==t.monitor and x and y and x>=t.x1 and x<=t.x2 and y>=t.y1 and y<=t.y2 then
        if t.name=="select_controller" then
          selectedTarget=t.data.target
          local _,groups=controllerGroups(lastMeta)
          local list=groups[tostring(selectedTarget)] or {}
          local hasSide=false
          for _,c in ipairs(list) do if c.side~=nil and tostring(c.side)~="" then hasSide=true break end end
          if not hasSide and list[1] then pending={target=list[1].target,side=nil,name="ROOM PANEL"}; setupStage="mode" else setupStage="side" end
          renderSetup(lastMeta); return true
        elseif t.name=="select_side" then
          pending=t.data; setupStage="mode"; renderSetup(lastMeta); return true
        elseif t.name=="select_mode" then
          local ok,res=commitSetup(t.data.mode,action)
          if ok then if base.render then base.render(lastEnv,lastMeta) end else renderSetup(lastMeta) end
          return ok,res
        end
      end
    end
    return false,"touch missed setup control"
  end
  if base.handleEvent then return base.handleEvent(ev,env,action) end
  return false
end

return M
