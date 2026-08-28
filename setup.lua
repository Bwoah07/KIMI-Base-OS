local monitorConfig=require("core.monitor_config")
local configModule=require("core.config")
local touchInput=require("core.touch_input")

local args={...}
local cmd=tostring(args[1]or"all"):lower()
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

local function screenSetup()
    local ms=monitors();if #ms==0 then return false,"no monitors detected" end
    local data=monitorConfig.load();local boxes={};local views=monitorConfig.views();local viewIndex={};for i,v in ipairs(views)do viewIndex[v]=i end
    local done=false;local saved=false
    local function drawOne(e)
        boxes[e.name]={};local b=boxes[e.name];local current=monitorConfig.get(data,e.name)
        e.mon.setBackgroundColor(C.bg);e.mon.setTextColor(C.text);e.mon.clear()
        put(e,2,1,"KIMI SCREEN SETUP",C.text);put(e,2,2,e.name,C.dim);put(e,2,3,tostring(e.w).."x"..tostring(e.h).."  CURRENT: "..current:upper(),C.good)
        if e.w>=36 and e.h>=18 then
            local cols=2;local rows=5;local gap=1;local top=5;local bottom=e.h-4;local cellH=math.max(2,math.floor((bottom-top+1-(rows-1)*gap)/rows));local cellW=math.floor((e.w-5)/2)
            for i,v in ipairs(views)do
                local col=(i-1)%cols;local row=math.floor((i-1)/cols);local x1=2+col*(cellW+1);local x2=col==1 and e.w-2 or x1+cellW-1;local y1=top+row*(cellH+gap);local y2=math.min(bottom,y1+cellH-1)
                button(e,b,x1,y1,x2,y2,v:upper(),"view:"..v,current==v and C.good or C.panel,current==v and C.bg or C.text)
            end
            button(e,b,2,e.h-2,math.floor(e.w/2)-1,e.h,"CANCEL","cancel",C.bad);button(e,b,math.floor(e.w/2)+1,e.h-2,e.w-2,e.h,"SAVE ALL","save",C.action)
        else
            center(e,6,current:upper(),C.good);put(e,2,8,"TAP PREV / NEXT ON THIS SCREEN",C.dim)
            local half=math.floor(e.w/2);button(e,b,2,10,half-1,12,"< PREV","prev",C.panel);button(e,b,half+1,10,e.w-2,12,"NEXT >","next",C.panel)
            button(e,b,2,math.max(14,e.h-2),half-1,e.h,"CANCEL","cancel",C.bad);button(e,b,half+1,math.max(14,e.h-2),e.w-2,e.h,"SAVE ALL","save",C.action)
        end
    end
    local function redraw()for _,e in ipairs(ms)do drawOne(e)end end
    redraw()
    while not done do
        local ev={os.pullEvent()}
        if ev[1]=="terminate"then done=true
        elseif ev[1]=="peripheral"or ev[1]=="peripheral_detach"then ms=monitors();if #ms==0 then done=true else redraw()end
        elseif ev[1]=="monitor_touch"then
            local name,x,y=ev[2],tonumber(ev[3])or 0,tonumber(ev[4])or 0;local id=hit(boxes[name],x,y)
            if id=="cancel"then done=true
            elseif id=="save"then monitorConfig.save(data);saved=true;done=true
            elseif id and id:sub(1,5)=="view:"then data=monitorConfig.set(data,name,id:sub(6));redraw()
            elseif id=="prev"or id=="next"then
                local cur=monitorConfig.get(data,name);local ix=viewIndex[cur]or 1;ix=ix+(id=="prev"and-1 or 1);if ix<1 then ix=#views elseif ix>#views then ix=1 end;data=monitorConfig.set(data,name,views[ix]);redraw()
            end
        end
    end
    for _,e in ipairs(ms)do e.mon.setBackgroundColor(C.bg);e.mon.setTextColor(C.text);e.mon.clear();center(e,2,saved and"KIMI SCREEN MAP SAVED"or"KIMI SCREEN SETUP CANCELLED",saved and C.good or C.warn)end
    return saved,saved and"saved"or"cancelled"
end

local function drawHome(e,status)
    local boxes={};local cfg=configModule.load();local name=tostring(cfg.name or((type(os.getComputerLabel)=="function"and os.getComputerLabel())or("KIMI-"..tostring(os.getComputerID()))))
    e.mon.setBackgroundColor(C.bg);e.mon.setTextColor(C.text);e.mon.clear()
    put(e,2,1,"KIMI SETUP",C.text);put(e,2,2,"COMPUTER ID "..tostring(os.getComputerID()).."  /  "..name:upper(),C.good)
    put(e,2,3,"EVERYTHING BELOW IS TOUCHSCREEN",C.dim)
    local x1,x2=2,e.w-2;local top=5;local bh=3;local gap=1
    button(e,boxes,x1,top,x2,top+bh-1,"COMPUTER NAME","name",C.action)
    button(e,boxes,x1,top+(bh+gap),x2,top+(bh+gap)+bh-1,"SCREEN ASSIGNMENTS","screens",C.panel)
    button(e,boxes,x1,top+2*(bh+gap),x2,top+2*(bh+gap)+bh-1,"DOOR SETUP","doors",C.panel)
    local bottom=e.h-3;local half=math.floor(e.w/2)
    button(e,boxes,2,bottom,half-1,e.h-1,"EXIT","exit",C.bad)
    button(e,boxes,half+1,bottom,e.w-2,e.h-1,"REBOOT / APPLY","reboot",C.good,C.bg)
    if status and status~=""then put(e,2,math.max(4,bottom-2),status,C.warn)end
    return boxes
end
local function touchHome()
    local ms=monitors();if #ms==0 then return false,"no monitor"end
    local e=ms[1];local status="";local boxes=drawHome(e,status)
    while true do
        local ev={os.pullEvent()}
        if ev[1]=="terminate"then return false,"cancelled"end
        if ev[1]=="peripheral"or ev[1]=="peripheral_detach"then
            ms=monitors();if #ms==0 then return false,"monitor detached"end;e=ms[1];boxes=drawHome(e,status)
        elseif ev[1]=="monitor_touch"and tostring(ev[2])==tostring(e.name)then
            local id=hit(boxes,tonumber(ev[3])or 0,tonumber(ev[4])or 0)
            if id=="exit"then e.mon.clear();center(e,2,"KIMI SETUP CLOSED",C.dim);return true
            elseif id=="reboot"then e.mon.clear();center(e,2,"APPLYING KIMI SETUP...",C.good);sleep(.3);os.reboot();return true
            elseif id=="name"then
                local ok,name,err=renameComputerTouch(e);status=ok and("SAVED NAME: "..tostring(name):upper())or("NAME UNCHANGED: "..tostring(err or"cancelled"));boxes=drawHome(e,status)
            elseif id=="screens"then
                local ok,why=screenSetup();status=ok and"SCREEN MAP SAVED"or("SCREEN MAP "..tostring(why or"UNCHANGED"):upper());ms=monitors();if #ms==0 then return false,"monitor detached"end;e=ms[1];boxes=drawHome(e,status)
            elseif id=="doors"then
                shell.run("door_setup");ms=monitors();if #ms==0 then return false,"monitor detached"end;e=ms[1];status="DOOR SETUP CLOSED";boxes=drawHome(e,status)
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
    shell.run("door_setup")
elseif cmd=="monitors"or cmd=="screens"then
    screenSetup()
elseif cmd=="name"then
    renameComputerTouch(ms[1])
else
    touchHome()
end
