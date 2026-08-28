package.path="./?.lua;./?/init.lua;"..package.path

local function fail(msg)error("alpha87: "..tostring(msg),0)end
local function ok(v,msg)if not v then fail(msg)end end
local function read(path)local f=assert(io.open(path,"r"));local s=f:read("*a");f:close();return s end

-- KIMI fleet IDs are presentation IDs. The physical CC/rednet transport ID is
-- deliberately untouched, while Main is always shown as KIMI ID 1.
package.loaded["core.fleet_display"]=nil
local display=require("core.fleet_display")
local fleet={
 [7]={name="MAIN SERVER",firstSeen=2000},
 [10]={name="UPPER DOOR",firstSeen=1000},
 [20]={name="REMOTE TWO",firstSeen=3000},
}
local rows=display.rows(fleet,7)
ok(#rows==3,"fleet display dropped rows")
ok(rows[1].transportId==7 and rows[1].displayId==1 and rows[1].main==true,"Main is not KIMI ID 1")
ok(display.displayId(fleet,7,10)==2,"first remote should be KIMI ID 2")
ok(display.displayId(fleet,7,20)==3,"second remote should be KIMI ID 3")

-- Fleet deletion is durable, OFFLINE-only, cannot delete Main, and requests a
-- reboot so the server's old in-memory fleet table cannot resurrect the ghost.
local current={
 [7]={name="MAIN SERVER",lastSeen=999000},
 [10]={name="UPPER DOOR",lastSeen=1000},
 [20]={name="REMOTE TWO",lastSeen=999000},
}
local saved,rebooted=nil,false
package.loaded["core.fleet_registry"]={
 load=function()local out={};for id,m in pairs(current)do local c={};for k,v in pairs(m)do c[k]=v end;out[id]=c end;return out end,
 save=function(m)saved=m;return true end,
}
package.loaded["core.fleet_health"]={
 reachability=function(id)
  if tonumber(id)==10 then return"OFFLINE",998000 end
  return"ONLINE",1000
 end,
}
local realGetId,realEpoch,realReboot=os.getComputerID,os.epoch,os.reboot
os.getComputerID=function()return 7 end
os.epoch=function()return 1000000 end
os.reboot=function()rebooted=true end
package.loaded["modules.fleet_admin"]=nil
local admin=require("modules.fleet_admin")
local result=admin.handleCommand("forget",{id=10})
ok(result and result.forgot==true,"offline ghost was not forgotten")
ok(saved and saved[10]==nil and saved[7]~=nil and saved[20]~=nil,"fleet delete removed wrong records")
ok(rebooted==true,"fleet delete did not reboot to make durable registry authoritative")

local selfOk=pcall(admin.handleCommand,"forget",{id=7})
ok(selfOk==false,"Main Server was allowed to forget itself")
local liveOk=pcall(admin.handleCommand,"forget",{id=20})
ok(liveOk==false,"reachable remote was allowed to be forgotten")
os.getComputerID,os.epoch,os.reboot=realGetId,realEpoch,realReboot

local adaptive=read("clients/admin_v29.lua")
ok(adaptive:find('require("core.fleet_display")',1,true),"AUTO Fleet is not using logical KIMI IDs")
ok(adaptive:find('"fleet_admin","forget"',1,true),"AUTO Fleet has no offline forget action")
ok(adaptive:find("TAP ID ",1,true)and adaptive:find("AGAIN TO FORGET",1,true),"AUTO Fleet lost two-tap delete confirmation")
local manual=read("clients/manual_dashboard.lua")
ok(manual:find('require("core.fleet_display")',1,true),"pinned Fleet is not using logical KIMI IDs")
ok(manual:find('"fleet_admin","forget"',1,true),"pinned Fleet has no offline forget action")
ok(manual:find("AGAIN TO FORGET",1,true),"pinned Fleet lost two-tap delete confirmation")
local setup=read("setup.lua")
ok(setup:find("KIMI ID ",1,true)and setup:find('cfg.role)=="server"and 1',1,true),"setup does not present Main as KIMI ID 1")

print("alpha87 fleet cleanup/logical-id smoke test OK")
