local M = {}

local C = {
  bg=colors.black, text=colors.white, dim=colors.lightGray,
  good=colors.lime, warn=colors.orange, bad=colors.red,
  action=colors.blue, panel=colors.gray,
}

local cfg={}
local targets={}
local lastEnv,lastMeta
local lastAction="READY"
local lastActionOk=true

local function upper(v) return tostring(v or ""):upper() end
local function roomName()
  local label=type(os.getComputerLabel)=="function" and os.getComputerLabel() or nil
  if label and tostring(label):match("%S") and not tostring(label):match("^KIMI[%s%-]?%d+$") then return upper(label) end
  if cfg.name and tostring(cfg.name):match("%S") and not tostring(cfg.name):match("^KIMI[%s%-]?%d+$") then return upper(cfg.name) end
  return "ROOM PANEL"
end
local function gameTimeValue()
  local ok,t=pcall(os.time,"ingame")
  return ok and tonumber(t) or 0
end
local function gameTime()
  local t=gameTimeValue()%24
  local h=math.floor(t)
  local m=math.floor(((t-h)*60)+0.5)%60
  return string.format("%02d:%02d",h,m)
end
local function dayNight()
  local h=gameTimeValue()%24
  return (h>=6 and h<18) and "DAY" or "NIGHT"
end
local function weather(env)
  local state=env and env.state or {}
  local e=state and state.environment or nil
  local w=upper(e and e.weather or "UNKNOWN")
  if w=="SUNNY" then w="CLEAR" end
  return w
end
local function weatherColor(w)
  if w=="THUNDER" then return C.bad end
  if w=="RAINING" or w=="RAIN" then return C.warn end
  if w=="CLEAR" then return C.good end
  return C.dim
end
local function isMonitor(name)
  local ok,t=pcall(peripheral.getType,name)
  if ok and t=="monitor" then return true end
  if ok and type(t)=="table" then for _,v in ipairs(t) do if v=="monitor" then return true end end end
  if type(peripheral.hasType)=="function" then local ok2,has=pcall(peripheral.hasType,name,"monitor"); if ok2 and has then return true end end
  return false
end
local function detectMonitors()
  local out={}
  local ok,names=pcall(peripheral.getNames)
  if not ok or type(names)~="table" then return out end
  for _,name in ipairs(names) do
    if isMonitor(name) then
      local okW,mon=pcall(peripheral.wrap,name)
      if okW and mon then
        local scale=1
        pcall(mon.setTextScale,scale)
        local okS,w,h=pcall(mon.getSize)
        if okS and tonumber(w) and tonumber(h) then
          w,h=tonumber(w),tonumber(h)
          if w<22 or h<12 then
            scale=.5; pcall(mon.setTextScale,scale)
            local ok2,w2,h2=pcall(mon.getSize)
            if ok2 then w,h=tonumber(w2) or w,tonumber(h2) or h end
          end
          out[#out+1]={name=name,mon=mon,w=w,h=h,scale=scale,area=w*h}
        end
      end
    end
  end
  table.sort(out,function(a,b) if a.area~=b.area then return a.area>b.area end if a.w~=b.w then return a.w>b.w end return a.name<b.name end)
  return out
end
local function put(e,x,y,text,fg,bg)
  if not e or y<1 or y>e.h or x>e.w then return end
  x=math.max(1,x); text=tostring(text or "")
  pcall(e.mon.setCursorPos,x,y); pcall(e.mon.setTextColor,fg or C.text); pcall(e.mon.setBackgroundColor,bg or C.bg); pcall(e.mon.write,text:sub(1,math.max(0,e.w-x+1)))
end
local function fill(e,x1,y1,x2,y2,bg)
  x1,x2=math.max(1,x1),math.min(e.w,x2); y1,y2=math.max(1,y1),math.min(e.h,y2)
  for y=y1,y2 do put(e,x1,y,string.rep(" ",math.max(0,x2-x1+1)),C.text,bg) end
end
local function center(e,y,text,fg,bg,x1,x2)
  x1,x2=x1 or 1,x2 or e.w; local width=math.max(1,x2-x1+1); text=tostring(text or "")
  if #text>width then text=text:sub(1,width) end
  put(e,x1+math.max(0,math.floor((width-#text)/2)),y,text,fg,bg)
end
local function rule(e,y) put(e,1,y,string.rep("-",e.w),C.panel) end
local function localDoors(meta)
  local s=meta and meta.localState or {}; local d=s.doors
  return d and d.localDoors or {}
end
local function button(e,name,x1,y1,x2,y2,label,data,bg)
  fill(e,x1,y1,x2,y2,bg or C.action)
  center(e,math.floor((y1+y2)/2),label,C.text,bg or C.action,x1+2,x2-2)
  targets[e.name]=targets[e.name] or {}
  targets[e.name][#targets[e.name]+1]={monitor=e,name=name,x1=x1,y1=y1,x2=x2,y2=y2,data=data}
end
local function renderMonitor(e,env,meta)
  targets[e.name]={}
  pcall(e.mon.setTextScale,e.scale); pcall(e.mon.setBackgroundColor,C.bg); pcall(e.mon.setTextColor,C.text); pcall(e.mon.clear)
  put(e,2,1,roomName(),C.text); put(e,math.max(2,e.w-6),1,gameTime(),C.dim); rule(e,2)
  put(e,2,3,meta and meta.connected==false and "BASE OFFLINE" or "BASE ONLINE",meta and meta.connected==false and C.warn or C.good)

  local d=localDoors(meta)[1]
  if not d then
    center(e,7,"DOOR NOT CONFIGURED",C.warn,nil,2,e.w-1)
    center(e,10,"RUN: door setup",C.dim,nil,2,e.w-1)
    return
  end

  local state=d.online==false and "OFFLINE" or (d.open and "OPEN" or "CLOSED")
  local stateColor=d.online==false and C.bad or (d.open and C.good or C.text)
  local w=weather(env)
  center(e,6,upper(d.name or "DOOR"),C.dim,nil,2,e.w-1)
  center(e,8,state,stateColor,nil,2,e.w-1)
  center(e,10,dayNight().."  |  "..w,weatherColor(w),nil,2,e.w-1)

  local mode=tostring(d.mode or "hold")
  local label=mode=="pulse" and "TRIGGER DOOR" or (d.open and "CLOSE DOOR" or "OPEN DOOR")
  button(e,"door_toggle",3,13,e.w-2,math.min(e.h-2,18),label,{_source=tostring(os.getComputerID()),target=d.target,side=d.side,id=d.id},d.open and C.good or C.action)
  if lastAction~="READY" and lastAction~="DONE" then center(e,math.min(e.h-1,20),lastAction,lastActionOk and C.good or C.bad,nil,2,e.w-1) end
end
local function terminalStatus(meta,env,mons)
  pcall(function()
    local d=localDoors(meta)[1]
    term.setBackgroundColor(C.bg); term.setTextColor(C.text); term.clear(); term.setCursorPos(1,1)
    term.setTextColor(C.good); print("KIMI ROOM")
    term.setTextColor(C.text); print(roomName()); print("")
    print(meta and meta.connected==false and "BASE: OFFLINE" or "BASE: ONLINE")
    print("MONITORS: "..tostring(#mons))
    if d then print("DOOR: "..tostring(d.name or "LOCAL DOOR")); print("STATE: "..(d.open and "OPEN" or "CLOSED")) else print("DOOR: NOT CONFIGURED") end
    print("TIME: "..gameTime().." "..dayNight()); print("WEATHER: "..weather(env)); print("")
    term.setTextColor(lastActionOk and C.good or C.bad); print("LAST: "..tostring(lastAction)); term.setTextColor(C.text)
  end)
end
local function renderAll(env,meta)
  local mons=detectMonitors()
  for _,e in ipairs(mons) do renderMonitor(e,env,meta) end
  terminalStatus(meta,env,mons)
end

function M.init(c) cfg=c or {}; targets={}; lastAction="READY"; lastActionOk=true end
function M.render(env,meta) lastEnv,lastMeta=env,meta; local ok,err=pcall(renderAll,env,meta); if not ok then lastAction="UI ERROR: "..tostring(err); lastActionOk=false end; return ok,err end
function M.onPeripheralChange() if lastEnv then return M.render(lastEnv,lastMeta) end end
function M.handleEvent(ev,env,action)
  if ev[1]~="monitor_touch" then return false end
  local name,x,y=ev[2],tonumber(ev[3]),tonumber(ev[4]); if not name or not x or not y then return false end
  for _,t in ipairs(targets[name] or {}) do
    if x>=t.x1 and x<=t.x2 and y>=t.y1 and y<=t.y2 and t.name=="door_toggle" then
      lastAction="SENDING..."; lastActionOk=true
      local d=localDoors(lastMeta)[1]; local mode=d and tostring(d.mode or "hold") or "hold"
      local ok,res=action("__local_doors",mode=="pulse" and "pulse" or "toggle",t.data)
      if ok==false then lastAction="ERROR: "..tostring(res); lastActionOk=false else lastAction="DONE"; lastActionOk=true end
      M.render(lastEnv,lastMeta)
      return ok,res
    end
  end
  return false
end

return M
