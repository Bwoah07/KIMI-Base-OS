local realPrint=print
local clock=10000
local progress=.40
os.epoch=function()return clock end

local methods={
 reader={"getBlockName","getBlockData","getBlockState","hasBlockEntity"},
 direct={"getProgress","isRunning","getEnergy"},
}
local types={reader="block_reader",direct="test_builder"}
peripheral={}
function peripheral.getNames()return{"reader","direct"}end
function peripheral.getMethods(name)return methods[name]or{}end
function peripheral.getType(name)return types[name]end
function peripheral.call(name,method)
 if name=="reader"then
  if method=="getBlockName"then return"rftoolsbuilder:builder"end
  if method=="getBlockData"then return{
   progress=progress,
   scan={x=5,y=42,z=7},
   minBox={x=0,y=0,z=0},maxBox={x=9,y=99,z=9},
   energy=50000,maxEnergy=100000,running=true,
  }end
  if method=="getBlockState"then return{}end
  if method=="hasBlockEntity"then return true end
 elseif name=="direct"then
  if method=="getProgress"then return .25 end
  if method=="isRunning"then return true end
  if method=="getEnergy"then return 1234 end
 end
end

local module=assert(loadfile("modules/builder.lua"))()
local first=module.read(nil)
assert(first.count==2,"expected Block Reader target plus direct builder")
local by={};for _,b in ipairs(first.builders)do by[b.peripheral]=b end
local r=assert(by.reader,"RFTools Builder behind Block Reader was not discovered")
assert(r.reader==true and r.source=="block_reader","reader source metadata missing")
assert(r.targetBlock=="rftoolsbuilder:builder","reader did not identify Builder target")
assert(math.abs((r.progress or 0)-40)<.001,"reader progress field not decoded")
assert(r.currentY==42 and r.currentX==5 and r.currentZ==7,"reader scan position not decoded")
assert(r.energy==50000 and r.energyCapacity==100000,"reader energy fields not decoded")
assert(r.running==true,"reader running state not decoded")
local d=assert(by.direct,"native/direct builder compatibility regressed")
assert(math.abs((d.progress or 0)-25)<.001 and d.running==true,"direct builder API regressed")

clock=20000;progress=.50
local second=module.read(first);local rr
for _,b in ipairs(second.builders)do if b.peripheral=="reader"then rr=b end end
assert(rr and rr.percentRate and math.abs(rr.percentRate-1)<.001,"reader progress rate was not derived")
assert(rr.etaSeconds and math.abs(rr.etaSeconds-50)<.01,"reader ETA was not derived")
realPrint("alpha76 RFTools Builder Block Reader smoke test OK")
