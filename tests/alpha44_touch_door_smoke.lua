local realPrint=print
colors={white=1,orange=2,magenta=4,lightBlue=8,yellow=16,lime=32,pink=64,gray=128,lightGray=256,cyan=512,purple=1024,blue=2048,brown=4096,green=8192,red=16384,black=32768}

local function surface(w,h)
  local rows,x,y={},1,1
  local s={}
  s.setTextScale=function()end
  s.setBackgroundColor=function()end
  s.setTextColor=function()end
  s.clear=function() rows={}; x,y=1,1 end
  s.setCursorPos=function(nx,ny) x,y=nx,ny end
  s.getCursorPos=function() return x,y end
  s.getSize=function() return w,h end
  s.write=function(v)
    v=tostring(v or "")
    if y<1 or y>h or x>w then return end
    v=v:sub(1,math.max(0,w-x+1))
    local row=rows[y] or string.rep(" ",w)
    rows[y]=row:sub(1,x-1)..v..row:sub(x+#v)
    x=x+#v
  end
  s.output=function()
    local out={}
    for i=1,h do out[i]=rows[i] or string.rep(" ",w) end
    return table.concat(out,"\n")
  end
  return s
end

local mon=surface(42,24)
local computerTerm=surface(26,20)
term=computerTerm
print=function(...)
  local parts={}
  for i=1,select("#",...) do parts[#parts+1]=tostring(select(i,...)) end
  term.write(table.concat(parts,"\t"))
  local _,cy=term.getCursorPos()
  term.setCursorPos(1,cy+1)
end

local devices={monitor={type="monitor",object=mon}}
peripheral={}
peripheral.getNames=function() return {"monitor"} end
peripheral.getType=function(name) return devices[name] and devices[name].type or nil end
peripheral.hasType=function(name,t) return devices[name] and devices[name].type==t or false end
peripheral.wrap=function(name) return devices[name] and devices[name].object or nil end
peripheral.getMethods=function() return {} end
peripheral.isPresent=function(name) return devices[name]~=nil end

local outputs={left=false}
redstone={}
redstone.getOutput=function(side) return outputs[side]==true end
redstone.setOutput=function(side,value) outputs[side]=value==true end
redstone.getInput=function() return false end

local persisted={{key="computer|left",name="FRONT GATE",target="computer",side="left",kind="digital_side",type="computer_redstone",mode="hold",pulseSeconds=.5}}
fs={}
fs.exists=function(path) return path==".kimi" or path==".kimi/local_doors" end
fs.isDir=function(path) return path==".kimi" end
fs.makeDir=function() end
fs.open=function(path,mode)
  if mode=="r" then return {readAll=function() return "door-state" end,close=function()end} end
  return {write=function()end,writeLine=function()end,close=function()end}
end
textutils={}
textutils.unserialize=function() return persisted end
textutils.serialize=function() return "door-state" end

os={}
os.getComputerID=function() return 42 end
os.getComputerLabel=function() return "Front Gate" end
os.time=function() return 12.0 end
os.epoch=function() return 1000 end

local doors=assert(loadfile("modules/doors.lua"))()
local room=assert(loadfile("clients/room_v12.lua"))()
room.init({name="KIMI-42"})

local function meta()
  return {connected=true,localState={doors=doors.read(),attachments={sensors={}}}}
end
local env={version="5.0.0-alpha.44",state={attachments={sensors={{type="environment_detector",metrics={temperature=21.5}}}}}}

local m=meta()
room.render(env,m)
local before=mon.output()
assert(before:find("OPEN DOOR",1,true),"OPEN DOOR button missing before touch")
assert(computerTerm.output():find("REDSTONE: OFF",1,true),"computer terminal did not show redstone OFF")

local callbackCalls=0
local ok,err=room.handleEvent({"monitor_touch","monitor",20,12},env,function(module,action,args)
  callbackCalls=callbackCalls+1
  assert(module=="__local_doors","touch routed to wrong module")
  assert(action=="toggle","touch routed to wrong action")
  return pcall(doors.handleCommand,action,args)
end)
assert(ok~=false,"door touch failed: "..tostring(err))
assert(callbackCalls==1,"monitor touch did not invoke action exactly once")
assert(outputs.left==true,"monitor touch did not set computer redstone output ON")

m=meta()
room.render(env,m)
local after=mon.output()
assert(after:find("REDSTONE ON",1,true),"monitor did not show live redstone ON")
assert(after:find("CLOSE DOOR",1,true),"monitor did not flip to CLOSE DOOR")
local termOut=computerTerm.output()
assert(termOut:find("REDSTONE: ON",1,true),"computer terminal did not show live redstone ON")
assert(termOut:find("TOUCH:",1,true),"computer terminal did not expose last monitor touch")

realPrint("alpha44 monitor-touch redstone smoke test OK")
