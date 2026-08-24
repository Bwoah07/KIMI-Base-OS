local realPrint=print
colors={white=1,orange=2,magenta=4,lightBlue=8,yellow=16,lime=32,pink=64,gray=128,lightGray=256,cyan=512,purple=1024,blue=2048,brown=4096,green=8192,red=16384,black=32768}

local outputs={west=false}
local methods={"setOutput","getOutput","getInput"}
peripheral={}
peripheral.getNames=function() return {"redstone_integrator_0"} end
peripheral.getType=function(name) return name=="redstone_integrator_0" and "redstone_integrator" or nil end
peripheral.getMethods=function(name) return name=="redstone_integrator_0" and methods or {} end
peripheral.call=function(name,method,...)
  assert(name=="redstone_integrator_0","wrong peripheral")
  local a={...}
  if method=="setOutput" then outputs[a[1]]=a[2]==true; return true end
  if method=="getOutput" then return outputs[a[1]]==true end
  if method=="getInput" then return false end
  error("unsupported method "..tostring(method))
end
peripheral.wrap=function() error("WRAP MUST NOT BE USED") end
peripheral.isPresent=function(name) return name=="redstone_integrator_0" end

redstone={getOutput=function()return false end,getInput=function()return false end,setOutput=function()end}
local saved={}
fs={}
fs.exists=function(path)return path==".kimi" or (#saved>0 and path==".kimi/local_doors")end
fs.isDir=function(path)return path==".kimi"end
fs.makeDir=function()end
fs.open=function(path,mode)
 if mode=="r" then return{readAll=function()return"saved"end,close=function()end}end
 return{write=function() saved={{key="redstone_integrator_0|west",name="VAULT",target="redstone_integrator_0",side="west",kind="digital_side",type="redstone_integrator",mode="hold",pulseSeconds=.5}} end,close=function()end}
end
textutils={serialize=function()return"saved"end,unserialize=function()return saved end}
os={epoch=function()return 1000 end}
sleep=function()end

local doors=assert(loadfile("modules/doors.lua"))()
local state=doors.read()
local found=false
for _,c in ipairs(state.candidates or{}) do if c.target=="redstone_integrator_0" and c.side=="west" then found=true end end
assert(found,"integrator west output not discovered")

doors.handleCommand("register_local",{target="redstone_integrator_0",side="west",name="VAULT"})
local result=doors.handleCommand("toggle",{target="redstone_integrator_0",side="west"})
assert(outputs.west==true,"peripheral.call setOutput did not turn west ON")
assert(result.signal==true and result.open==true,"toggle result did not report open")

state=doors.read()
assert(state.localDoorCount==1,"saved local door missing")
assert(state.localDoors[1].signal==true,"live integrator output not read back")

realPrint("alpha45 peripheral.call door smoke test OK")