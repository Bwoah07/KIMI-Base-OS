local monitorConfig=require("core.monitor_config")
local configModule=require("core.config")
local touchInput=require("core.touch_input")

local args={...}
local cmd=tostring(args[1]or"all"):lower()
local requestedMonitor=tostring(args[2]or"")
local C={bg=colors.black,text=colors.white,dim=colors.lightGray,good=colors.lime,warn=colors.orange,bad=colors.red,panel=colors.gray,action=colors.blue}

local function isMonitor(name)
    local ok,t=pcall(peripheral.getType,name);if ok and t=="monitor"then return true end
    if type(peripheral.hasType)=="function"then local ok2,v=pcall(peripheral.hasType,name,"monitor");if ok2 and v then return true end end
    return false
end
local function monitors()
    local out={};local ok,names=pcall(peripheral.getNames);if not ok or type(names)~="table"then return out end
    for _,name in ipairs(names)do if isMonitor(name)then
        local okw,mon=pcall(peripheral.wrap,name);if okw and mon then
            pcall(mon.setTextScale,.5);local oks,w,h=pcall(mon.getSize)
            if oks then out[#out+1]={name=name,mon=mon,w=tonumber(w),h=tonumber(h),area=(tonumber(w)or 0)*(tonumber(h)or 0)}end
        end
    end end
    table.sort(out,function(a,b)if a.area~=b.area then return a.area>b.area end;return a.name<b.name end)
    return out
end
local function findMonitor(ms,name)
    name=tostring(name or"");if name==""then return nil end
    for _,e in ipairs(ms or{})do if tostring(e.name)==name then return e end end
end
local function put(e,x,y,text,fg,bg)
    if not e or y<1 or y>e.h or x>e.w then return end
    text=tostring(text or"");e.mon.setCursorPos(math.max(1,x),y);e.mon.setBackgroundColor(bg or C.bg);e.mon.setTextColor(fg or C.text);e.mon.write(text:sub(1,math.max(0,e.w-x+1)));e.mon.setBackgroundColor(C.bg)
end
local function fill(e,x1,y1,x2,y2,bg)
    x1,x2=math.max(1,x1),math.min(e.w,x2);y1,y2=math.max(1,y1),math.min(e.h,y2);if x2<x1 or y2<y1 then return end
    for y=y1,y2 do put(e,x1,y,string.rep(" ",x2-x1+1),C.text,bg)end
end
local function center(e,y,text,fg,bg,x1,x2)
    x1,x2=x1 or 1,x2 or e.w;local w=x2-x1+1;text=tostring(text or"");if #text>w then text=text:sub(1,w)end
    put(e,x1+math.max(0,math.floor((w-#text)/2)),y,text,fg,bg)
end
local function button(e,boxes,x1,y1,x2,y2,label,id,bg,fg)
    fill(e,x1,y1,x2,y2,bg or C.panel);center(e,math.floor((y1+y2)/2),label,fg or C.text,bg or C.panel,x1,x2)
    boxes[#boxes+1]={x1=x1,y1=y1,x2=x2,y2=y2,id=id}
end
local function hit(boxes,x,y)
    for _,b in ipairs(boxes or{})do if x>=b.x1 and x<=b.x2 and y>=b.y1 and y<=b.y2 then return b.id end end
end

local function saveComputerName(name)
    name=touchInput.sanitize(name,28);if name==""then return false,"empty name"end
    local cfg=configModule.load();cfg.name=name;configModule.save(cfg)
    if type(os.setComputerLabel)=="function"then pcall(os.setComputerLabel,name)end
    return true,name
end
local function renameComputerTouch(e)
    local cfg=configModule.load();local current=tostring(cfg.name or((type(os.getComputerLabel)=="function"and os.getComputerLabel())or("KIMI-"..tostring(os.getComputerID()))))
    local name,ok,err=touchInput.read(e,{title="KIMI COMPUTER NAME",subtitle="NAME THIS COMPUTER - TOUCH ONLY",value=current,maxLen=28})
    if not ok then return false,current,err end
    local saved,value=saveComputerName(name);return saved,value
end
local function renameComputerTerminal()
    local cfg=configModule.load();local current=tostring(cfg.name or("KIMI-"..tostring(os.getComputerID())))
    term.clear();term.setCursorPos(1,1);print("KIMI COMPUTER SETUP");print("Current name: "..current);write("Computer name [keep current]: ")
    local name=read();if not name or not name:match("%S")then return false,current end
    return saveComputerName(name)
end

local function drawChooser(ms,msg)
    local map=monitorConfig.load()
    for _,e in ipairs(ms or{})do
        e.mon.setBackgroundColor(C.bg);e.mon.setTextColor(C.text);e.mon.clear()
        put(e,2,1,"KIMI SETUP",C.text);put(e,2,2,e.name,C.dim)
        center(e,5,"TOUCH THIS SCREEN",C.good)
        center(e,7,"TO CONFIGURE THIS EXACT MONITOR",C.text)
        center(e,9,"CURRENT: "..monitorConfig.get(map,e.name):upper(),C.warn)
        if msg and msg~=""then center(e,math.min(e.h-2,12),msg,C.dim)end
    end
end
local function chooseMonitor(preferred,msg)
    local ms=monitors();if #ms==0 then return nil,"no monitor"end
    local exact=findMonitor(ms,preferred);if exact then return exact end
    drawChooser(ms,msg)
    while true do
        local ev={os.pullEvent()}
        if ev[1]=="terminate"then return nil,"cancelled"end
        if ev[1]=="peripheral"or ev[1]=="peripheral_detach"then
            ms=monitors();if #ms==0 then return nil,"monitor detached"end;drawChooser(ms,msg)
        elseif ev[1]=="monitor_touch"then
            local e=findMonitor(ms,ev[2]);if e then return e end
        end
    end
end

local function screenSetupOne(e)
    if not e then return false,"no monitor"end
    local data=monitorConfig.load();local boxes={};local views=monitorConfig.views();local viewIndex={};for i,v in ipairs(views)do viewIndex[v]=i end
    local current=monitorConfig.get(data,e.name);local done=false;local saved=false
    local function draw()
        boxes={};current=monitorConfig.get(data,e.name)
        e.mon.setBackgroundColor(C.bg);e.mon.setTextColor(C.text);e.mon.clear()
        put(e,2,1,"KIMI SCREEN SETUP",C.text);put(e,2,2,e.name,C.dim);put(e,2,3,"CURRENT: "..current:upper(),C.good)
        if e.w>=36 and e.h>=18 then
            local cols=2;local rows=5;local gap=1;local top=5;local bottom=e.h-4;local cellH=math.max(2,math.floor((bottom-top+1-(rows-1)*gap)/rows));local cellW=math.floor((e.w-5)/2)
            for i,v in ipairs(views)do
                local col=(i-1)%cols;local row=math.floor((i-1)/cols);local x1=2+col*(cellW+1);local x2=col==1 and e.w-2 or x1+cellW-1;local y1=top+row*(cellH+gap);local y2=math.min(bottom,y1+cellH-1)
                button(e,boxes,x1,y1,x2,y2,v:upper(),"view:"..v,current==v and C.good or C.panel,current==v and C.bg or C.text)
            end
            button(e,boxes,2,e.h-2,math.floor(e.w/2)-1,e.h,"CANCEL","cancel",C.bad);button(e,boxes,math.floor(e.w/2)+1,e.h-2,e.w-2,e.h,"SAVE THIS SCREEN","save",C.action)
        else
            center(e,6,current:upper(),C.good);put(e,2,8,"TAP PREV / NEXT",C.dim)
            local half=math.floor(e.w/2);button(e,boxes,2,10,half-1,12,"< PREV","prev",C.panel);button(e,boxes,half+1,10,e.w-2,12,"NEXT >","next",C.panel)
            button(e,boxes,2,math.max(14,e.h-2),half-1,e.h,"CANCEL","cancel",C.bad);button(e,boxes,half+1,math.max(14,e.h-2),e.w-2,e.h,"SAVE","save",C.action)
        end
    end
    draw()
    while not done do
        local ev={os.pullEvent()}
        if ev[1]=="terminate"then done=true
        elseif ev[1]=="peripheral_detach"and tostring(ev[2])==tostring(e.name)then return false,"monitor detached"
        elseif ev[1]=="monitor_touch"and tostring(ev[2])==tostring(e.name)then
            local id=hit(boxes,tonumber(ev[3])or 0,tonumber(ev[4])or 0)
            if id=="cancel"then done=true
            elseif id=="save"then monitorConfig.save(data);saved=true;done=true
            elseif id and id:sub(1,5)=="view:"then data=monitorConfig.set(data,e.name,id:sub(6));draw()
            elseif id=="prev"or id=="next"then
                local ix=viewIndex[monitorConfig.get(data,e.name)]or 1;ix=ix+(id=="prev"and-1 or 1);if ix<1 then ix=#views elseif ix>#views then ix=1 end;data=monitorConfig.set(data,e.name,views[ix]);draw()
            end
        end
    end
    if saved then e.mon.clear();center(e,2,"SAVED: "..monitorConfig.get(data,e.name):upper(),C.good)end
    return saved,saved and"saved"or"cancelled"
end

local function drawHome(e,status,dirty)
    local boxes={};local cfg=configModule.load();local map=monitorConfig.load();local name=tostring(cfg.name or((type(os.getComputerLabel)=="function"and os.getComputerLabel())or("KIMI-"..tostring(os.getComputerID()))))
    e.mon.setBackgroundColor(C.bg);e.mon.setTextColor(C.text);e.mon.clear()
    put(e,2,1,"KIMI SETUP",C.text);put(e,2,2,"ID "..tostring(os.getComputerID()).." / "..name:upper(),C.good)
    put(e,2,3,e.name.." = "..monitorConfig.get(map,e.name):upper(),C.dim)
    local x1,x2=2,e.w-2;local top=5;local gap=1;local bottom=e.h-3
    local available=math.max(4,bottom-top);local bh=math.max(1,math.min(3,math.floor((available-3*gap)/4)))
    local y=top
    button(e,boxes,x1,y,x2,math.min(bottom-1,y+bh-1),"COMPUTER NAME","name",C.action);y=y+bh+gap
    button(e,boxes,x1,y,x2,math.min(bottom-1,y+bh-1),"THIS SCREEN VIEW","screens",C.panel);y=y+bh+gap
    button(e,boxes,x1,y,x2,math.min(bottom-1,y+bh-1),"DOOR SETUP","doors",C.panel);y=y+bh+gap
    button(e,boxes,x1,y,x2,math.min(bottom-1,y+bh-1),"CHOOSE OTHER SCREEN","other",C.panel)
    if status and status~=""then put(e,2,math.max(4,bottom-1),status,C.warn)end
    local half=math.floor(e.w/2);button(e,boxes,2,bottom,half-1,e.h,"EXIT"..(dirty and" / APPLY"or""),"exit",C.bad);button(e,boxes,half+1,bottom,e.w-2,e.h,"REBOOT / APPLY","reboot",C.good,C.bg)
    return boxes
end

local function touchHome(preferred)
    local e,why=chooseMonitor(preferred,"PICK THE SCREEN YOU ARE STANDING AT");if not e then return false,why end
    local status="";local dirty=false
    while true do
        local boxes=drawHome(e,status,dirty);local ev={os.pullEvent()}
        if ev[1]=="terminate"then return false,"cancelled"end
        if ev[1]=="peripheral_detach"and tostring(ev[2])==tostring(e.name)then
            e,why=chooseMonitor(nil,"SETUP SCREEN DETACHED - PICK ANOTHER");if not e then return false,why end
        elseif ev[1]=="monitor_touch"and tostring(ev[2])==tostring(e.name)then
            local id=hit(boxes,tonumber(ev[3])or 0,tonumber(ev[4])or 0)
            if id=="exit"then
                if dirty then e.mon.clear();center(e,2,"APPLYING SETUP...",C.good);sleep(.3);os.reboot();return true end
                e.mon.clear();center(e,2,"KIMI SETUP CLOSED",C.dim);return true
            elseif id=="reboot"then e.mon.clear();center(e,2,"APPLYING KIMI SETUP...",C.good);sleep(.3);os.reboot();return true
            elseif id=="name"then
                local ok,name,err=renameComputerTouch(e);status=ok and("SAVED NAME: "..tostring(name):upper())or("NAME UNCHANGED: "..tostring(err or"cancelled"))
            elseif id=="screens"then
                local ok,reason=screenSetupOne(e);if ok then dirty=true;status="SAVED SCREEN: "..monitorConfig.get(monitorConfig.load(),e.name):upper()else status="SCREEN "..tostring(reason or"UNCHANGED"):upper()end
            elseif id=="doors"then
                shell.run("door_setup",e.name);status="DOOR SETUP CLOSED"
            elseif id=="other"then
                local nextE,nextWhy=chooseMonitor(nil,"TOUCH THE NEXT SCREEN TO CONFIGURE");if nextE then e=nextE;status=""else status=tostring(nextWhy or"NO SCREEN")end
            end
        end
    end
end

local ms=monitors()
if #ms==0 then
    if cmd=="doors"or cmd=="door"then shell.run("door_setup")
    elseif cmd=="monitors"or cmd=="screens"then print("[KIMI] no monitor attached; screen setup unavailable")
    else renameComputerTerminal() end
elseif cmd=="doors"or cmd=="door"then
    local e=chooseMonitor(requestedMonitor,"TOUCH THE SCREEN FOR DOOR SETUP");if e then shell.run("door_setup",e.name)end
elseif cmd=="monitors"or cmd=="screens"then
    local e=chooseMonitor(requestedMonitor,"TOUCH THE SCREEN TO ASSIGN");if e then screenSetupOne(e)end
elseif cmd=="name"then
    local e=chooseMonitor(requestedMonitor,"TOUCH THE SCREEN FOR NAMING");if e then renameComputerTouch(e)end
else
    touchHome(requestedMonitor)
end
