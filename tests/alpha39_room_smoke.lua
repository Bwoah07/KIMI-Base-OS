local realPrint=print
colors={white=1,orange=2,magenta=4,lightBlue=8,yellow=16,lime=32,pink=64,gray=128,lightGray=256,cyan=512,purple=1024,blue=2048,brown=4096,green=8192,red=16384,black=32768}

local function surface(width,height)
  local rows,x,y={},1,1
  local s={}
  s.setTextScale=function()end; s.setBackgroundColor=function()end; s.setTextColor=function()end
  s.clear=function() rows={}; x,y=1,1 end; s.setCursorPos=function(nx,ny)x,y=nx,ny end; s.getSize=function()return width,height end
  s.write=function(value)
    value=tostring(value or "")
    if y<1 or y>height or x>width then return end
    value=value:sub(1,math.max(0,width-x+1))
    local row=rows[y] or string.rep(" ",width)
    rows[y]=row:sub(1,x-1)..value..row:sub(x+#value)
    x=x+#value
  end
  s.output=function()
    local out={}; for i=1,height do out[i]=rows[i] or string.rep(" ",width) end
    return table.concat(out,"\n")
  end
  return s
end

local devices={}
peripheral={}
peripheral.getNames=function() local out={}; for n in pairs(devices) do out[#out+1]=n end; table.sort(out); return out end
peripheral.hasType=function(name,wanted) return devices[name] and devices[name].type==wanted or false end
peripheral.wrap=function(name) return devices[name] and devices[name].object end
term={clear=function()end,setCursorPos=function()end,setTextColor=function()end}
os={
  getComputerID=function()return 42 end,
  getComputerLabel=function()return "Front Gate" end,
  time=function()return 20.5 end,
}

local main=surface(42,24)
local second=surface(28,18)
local third=surface(22,14)
devices.a={type="monitor",object=main}
devices.b={type="monitor",object=second}
devices.c={type="monitor",object=third}

local room=assert(loadfile("clients/room_v8.lua"))()
room.init({name="KIMI-42"})

local meta={
  connected=true,
  localState={
    doors={localDoors={{id="local:redstone_integrator_0|west",name="FRONT GATE",target="redstone_integrator_0",side="west",mode="hold",online=true,open=false}},candidates={}},
    attachments={sensors={},devices={{name="modem",type="modem"},{name="a",type="monitor"}},diagnostics={onlyInfrastructure=true},dataCount=0}
  }
}
local env={version="5.0.0-alpha.39",state={}}
room.render(env,meta)

local out=main.output()
assert(out:find("FRONT GATE",1,true),"room door name missing")
assert(out:find("CLOSED",1,true),"door state missing")
assert(out:find("OPEN DOOR",1,true),"door action label disappeared from button")
assert(out:find("SENSOR OFFLINE",1,true),"sensor offline status missing")
assert(out:find("WIRE DETECTOR VIA MODEM",1,true),"short sensor wiring instruction missing")
assert(not out:find("WIRE DETECTOR TO THIS COMPUTER OR USE A WIRED MODEM",1,true),"verbose clipped sensor warning regressed")

local called
room.handleEvent({"monitor_touch","a",20,13},env,function(module,action,args)
  called={module=module,action=action,args=args}
  return true,{}
end)
assert(called and called.module=="__local_doors" and called.action=="toggle","door button did not route locally")

local out2=second.output()
assert(out2:find("LOCAL SENSOR",1,true),"second monitor was not automatically assigned to sensor/status duty")
local out3=third.output()
assert(out3:find("MAIN BASE ONLINE",1,true),"third monitor was not automatically populated with base status")

realPrint("alpha39 room smoke test OK")
