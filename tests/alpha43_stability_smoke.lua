local realPrint=print
colors={white=1,orange=2,magenta=4,lightBlue=8,yellow=16,lime=32,pink=64,gray=128,lightGray=256,cyan=512,purple=1024,blue=2048,brown=4096,green=8192,red=16384,black=32768}
keys={left=203,right=205,r=19}

local function read(path)
  local f=assert(io.open(path,"r"),"missing file: "..path)
  local s=f:read("*a"); f:close(); return s
end
local function exists(path)
  local f=io.open(path,"r"); if f then f:close(); return true end; return false
end

local installer=read("installer.lua")
local manifest=read("manifest.json")
local contracts={
  {needle='role,profile,localUI="server","admin",true', profile="admin"},
  {needle='role,profile,localUI="server","terminal",false', profile="terminal"},
  {needle='role,profile,localUI="client","wall",false', profile="wall"},
  {needle='role,profile,localUI="client","pocket",false', profile="pocket"},
}
for _,c in ipairs(contracts) do
  assert(installer:find(c.needle,1,true),"installer contract missing for "..c.profile)
  local path="clients/"..c.profile..".lua"
  assert(exists(path),"installer points to missing profile: "..path)
  assert(manifest:find('"'..path..'"',1,true),"profile not managed by release manifest: "..path)
end
for _,path in ipairs({"roles/server_v2.lua","roles/client.lua","roles/node.lua","clients/admin.lua","clients/wall.lua","clients/pocket.lua","clients/terminal.lua"}) do
  assert(exists(path),"runtime contract missing: "..path)
end

local W,H=26,20
local rows,x,y={},1,1
term={}
term.getSize=function() return W,H end
term.setBackgroundColor=function()end
term.setTextColor=function()end
term.clear=function() rows={}; x,y=1,1 end
term.setCursorPos=function(nx,ny) x,y=nx,ny end
term.write=function(v)
  v=tostring(v or"")
  if y<1 or y>H or x>W then return end
  v=v:sub(1,math.max(0,W-x+1))
  local row=rows[y] or string.rep(" ",W)
  rows[y]=row:sub(1,x-1)..v..row:sub(x+#v)
  x=x+#v
end
local function output()
  local o={}; for i=1,H do o[i]=rows[i] or string.rep(" ",W) end
  return table.concat(o,"\n")
end
os={getComputerID=function()return 88 end,getComputerLabel=function()return "Pocket Ops" end,time=function()return 12.5 end,epoch=function()return 1000 end}

local pocket=assert(loadfile("clients/pocket.lua"))()
pocket.init({name="KIMI-88"})
local env={version="5.0.0-alpha.43",state={fleet={[1]={online=true,version="5.0.0-alpha.43",name="Main Base"},[88]={online=true,version="5.0.0-alpha.43",name="Pocket Ops"}},doors={doors={{name="Front Gate",open=false}}},attachments={sensors={{type="environment_detector",summary="plains",metrics={temperature=21.5}}}},power={stored=900,capacity=1000,input=40,output=10,filledPercentage=.9}}}
local meta={connected=true,localVersion="5.0.0-alpha.43"}
assert(pocket.render(env,meta)~=false,"pocket render failed")
local out=output()
assert(out:find("POCKET OPS",1,true),"pocket title missing")
assert(out:find("BASE ONLINE",1,true),"pocket server state missing")
assert(out:find("FLEET",1,true),"pocket fleet summary missing")
assert(out:find("90.0%%"),"pocket power summary missing")
assert(out:find("< HOME >",1,true),"pocket footer/navigation missing")
assert(pocket.handleEvent({"key",keys.right},env,function()end)==true,"pocket right navigation failed")
out=output(); assert(out:find("DOORS  1",1,true),"pocket doors page did not render")
assert(pocket.handleEvent({"key",keys.right},env,function()end)==true,"pocket second navigation failed")
out=output(); assert(out:find("POWER",1,true),"pocket power page did not render")
assert(pocket.handleEvent({"key",keys.right},env,function()end)==true,"pocket third navigation failed")
out=output(); assert(out:find("SENSORS  1",1,true),"pocket sensors page did not render")
realPrint("alpha43 stability smoke test OK")
