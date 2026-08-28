local doors=require("modules.doors")
local touchInput=require("core.touch_input")

local C={bg=colors.black,text=colors.white,dim=colors.lightGray,good=colors.lime,warn=colors.orange,bad=colors.red,panel=colors.gray,action=colors.blue}
local selected=nil
local mode="hold"
local pulseSeconds=.5
local status=""
local page=1
local hitboxes={}

local function upper(v)return tostring(v or""):upper()end
local function nice(v)return upper(tostring(v or""):gsub("[_%-]"," "):gsub("(%l)(%u)","%1 %2"))end

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
local function button(e,x1,y1,x2,y2,label,id,bg)
    fill(e,x1,y1,x2,y2,bg or C.action);center(e,math.floor((y1+y2)/2),label,C.text,bg or C.action,x1,x2)
    hitboxes[#hitboxes+1]={x1=x1,y1=y1,x2=x2,y2=y2,id=id}
end
local function hit(x,y)
    for _,b in ipairs(hitboxes)do if x>=b.x1 and x<=b.x2 and y>=b.y1 and y<=b.y2 then return b.id end end
end

local function snapshot()
    local ok,s=pcall(doors.read);if ok and type(s)=="table"then return s end
    return{candidates={},localDoors={}}
end
local function candidates()
    local s=snapshot();local out={}
    for _,c in ipairs(s.candidates or{})do out[#out+1]=c end
    table.sort(out,function(a,b)
        if (a.localConfigured==true)~=(b.localConfigured==true)then return a.localConfigured==true end
        local aa=tostring(a.controller or a.target).."/"..tostring(a.side or"");local bb=tostring(b.controller or b.target).."/"..tostring(b.side or"");return aa<bb
    end)
    return out
end
local function configured(target,side)
    for _,d in ipairs(snapshot().localDoors or{})do if tostring(d.target)==tostring(target)and tostring(d.side or"")==tostring(side or"")then return d end end
end

local function rawSet(c,on)
    if not c then return false,"no candidate selected"end
    local target=tostring(c.target or"");local side=c.side
    if target=="computer"then
        local ok,err=pcall(redstone.setOutput,side,on==true);return ok,ok and nil or tostring(err)
    end
    local kind=tostring(c.kind or"")
    if kind=="digital_side"then local ok,err=pcall(peripheral.call,target,"setOutput",side,on==true);return ok,ok and nil or tostring(err)end
    if kind=="analog_side"then
        local methods={};local okm,list=pcall(peripheral.getMethods,target);if okm and type(list)=="table"then for _,m in ipairs(list)do methods[m]=true end end
        local method=methods.setAnalogOutput and"setAnalogOutput"or"setAnalogueOutput";local ok,err=pcall(peripheral.call,target,method,side,on and 15 or 0);return ok,ok and nil or tostring(err)
    end
    if kind=="native_door"then
        local ok,err=pcall(peripheral.call,target,"setOpen",on==true);if ok then return true end
        ok,err=pcall(peripheral.call,target,on and"open"or"close");return ok,ok and nil or tostring(err)
    end
    if kind=="enabled_actuator"then local ok,err=pcall(peripheral.call,target,"setEnabled",on==true);return ok,ok and nil or tostring(err)end
    if kind=="active_actuator"then local ok,err=pcall(peripheral.call,target,"setActive",on==true);return ok,ok and nil or tostring(err)end
    return false,"unsupported actuator kind"
end

local function drawList(e)
    hitboxes={};selected=nil;e.mon.setBackgroundColor(C.bg);e.mon.setTextColor(C.text);e.mon.clear()
    put(e,2,1,"KIMI DOOR SETUP",C.text);put(e,2,2,"EXPLICIT CONTROLLER + SIDE. NOTHING IS GUESSED.",C.dim)
    local list=candidates();local rows=math.max(1,math.floor((e.h-8)/2));local pages=math.max(1,math.ceil(#list/rows));page=math.max(1,math.min(page,pages));local first=(page-1)*rows+1
    put(e,2,4,"PAGE "..page.."/"..pages.."  CHANNELS "..#list,C.dim)
    local y=6
    for i=first,math.min(#list,first+rows-1)do
        local c=list[i];local tag=c.localConfigured and"CONFIGURED"or"AVAILABLE";local fg=c.localConfigured and C.good or C.text
        put(e,2,y,nice(c.controller or c.target).." / "..upper(c.side or"DOOR"),fg);put(e,math.max(2,e.w-#tag-1),y,tag,c.localConfigured and C.good or C.dim)
        put(e,2,y+1,nice(c.type).."  "..nice(c.kind).."  "..upper(c.sideModel or""),C.dim)
        hitboxes[#hitboxes+1]={x1=1,y1=y,x2=e.w,y2=y+1,id="pick:"..i};y=y+2
    end
    local by=e.h-2;local third=math.floor((e.w-4)/3)
    button(e,2,by,2+third-1,e.h,"< PREV","prev",C.panel);button(e,3+third,by,3+third*2-1,e.h,"EXIT","exit",C.bad);button(e,4+third*2,by,e.w-1,e.h,"NEXT >","next",C.panel)
end

local function drawDetail(e,c)
    hitboxes={};e.mon.setBackgroundColor(C.bg);e.mon.setTextColor(C.text);e.mon.clear()
    local old=configured(c.target,c.side);if old then mode=tostring(old.mode or"hold");pulseSeconds=tonumber(old.pulseSeconds)or.5 end
    put(e,2,1,"KIMI DOOR SETUP",C.text);put(e,2,2,old and("EDIT "..upper(old.name or"DOOR"))or"NEW DOOR",old and C.good or C.dim)
    put(e,2,4,"CONTROLLER",C.dim);put(e,14,4,nice(c.controller or c.target),C.text)
    put(e,2,5,"TARGET",C.dim);put(e,14,5,tostring(c.target),C.text)
    put(e,2,6,"SIDE",C.dim);put(e,14,6,upper(c.side or"DOOR").."  ("..upper(c.sideModel or"N/A")..")",C.text)
    put(e,2,7,"TYPE",C.dim);put(e,14,7,nice(c.type).." / "..nice(c.kind),C.text)
    local half=math.floor(e.w/2)
    button(e,2,9,half-1,11,"RAW OFF","raw_off",C.panel);button(e,half+1,9,e.w-2,11,"RAW ON","raw_on",C.warn)
    put(e,2,13,"BEHAVIOR",C.dim)
    local w=math.floor((e.w-6)/3);button(e,2,14,1+w,16,"HOLD","mode_hold",mode=="hold"and C.good or C.panel);button(e,3+w,14,2+w*2,16,"INVERT","mode_invert",mode=="invert"and C.good or C.panel);button(e,4+w*2,14,e.w-2,16,"PULSE","mode_pulse",mode=="pulse"and C.good or C.panel)
    if mode=="pulse"then put(e,2,18,"PULSE "..tostring(pulseSeconds).."s",C.dim);button(e,18,18,30,19,"0.25","pulse_025",pulseSeconds==.25 and C.good or C.panel);button(e,32,18,44,19,"0.5","pulse_05",pulseSeconds==.5 and C.good or C.panel);button(e,46,18,58,19,"1.0","pulse_10",pulseSeconds==1 and C.good or C.panel)end
    local by=e.h-3;button(e,2,by,math.floor(e.w*.32),e.h-1,"BACK","back",C.panel);button(e,math.floor(e.w*.34),by,math.floor(e.w*.66),e.h-1,old and"UPDATE"or"SAVE","save",C.good)
    if old then button(e,math.floor(e.w*.68),by,e.w-2,e.h-1,"REMOVE","remove",C.bad)end
    if status~=""then put(e,2,math.max(20,by-2),status,status:find("FAILED",1,true)and C.bad or C.warn)end
end

local function readNameTerminal(default)
    term.setBackgroundColor(colors.black);term.setTextColor(colors.white);term.clear();term.setCursorPos(1,1)
    print("KIMI Door Setup");write("Name ["..tostring(default or"DOOR").."]: ")
    local v=read();if not v or not v:match("%S")then return default or"DOOR"end
    return v
end
local function readNameTouch(e,default)
    local name,ok,err=touchInput.read(e,{title="KIMI DOOR NAME",subtitle="NAME THIS DOOR - TOUCH ONLY",value=default or"DOOR",maxLen=28})
    if not ok then return nil,err end
    return name
end

local function terminalFallback()
    local list=candidates();if #list==0 then print("[KIMI] no door-capable controllers detected");return end
    term.clear();term.setCursorPos(1,1);print("KIMI DOOR SETUP")
    for i,c in ipairs(list)do print(string.format("%d) %s / %s / %s%s",i,tostring(c.controller or c.target),tostring(c.side or"DOOR"),tostring(c.kind),c.localConfigured and" [configured]"or""))end
    write("Channel number: ");local ix=tonumber(read());local c=list[ix or 0];if not c then print("Invalid selection");return end
    write("Mode hold/invert/pulse [hold]: ");local m=tostring(read()or""):lower();if m~="invert"and m~="pulse"then m="hold"end
    local old=configured(c.target,c.side);local name=readNameTerminal(old and old.name or"DOOR")
    if not old then local ok,err=pcall(doors.handleCommand,"register_local",{target=c.target,side=c.side,name=name});if not ok then error(err,0)end end
    local ok,err=pcall(doors.handleCommand,"configure_local",{target=c.target,side=c.side,name=name,mode=m,pulseSeconds=.5});if not ok then error(err,0)end
    print("Saved. KIMI will publish it on the next refresh.")
end

local ms=monitors();if #ms==0 then terminalFallback();return end
local e=ms[1];drawList(e)
while true do
    local ev={os.pullEvent()}
    if ev[1]=="terminate"then break end
    if ev[1]=="peripheral"or ev[1]=="peripheral_detach"then ms=monitors();if #ms==0 then break end;e=ms[1];drawList(e)
    elseif ev[1]=="monitor_touch"and ev[2]==e.name then
        local id=hit(tonumber(ev[3])or 0,tonumber(ev[4])or 0)
        if id=="exit"then rawSet(selected,false);break
        elseif id=="prev"then page=math.max(1,page-1);drawList(e)
        elseif id=="next"then page=page+1;drawList(e)
        elseif id=="back"then rawSet(selected,false);status="";drawList(e)
        elseif id=="raw_on"then local ok,err=rawSet(selected,true);status=ok and"RAW SIGNAL ON - VERIFY THE PHYSICAL DOOR"or("TEST FAILED: "..tostring(err));drawDetail(e,selected)
        elseif id=="raw_off"then local ok,err=rawSet(selected,false);status=ok and"RAW SIGNAL OFF - VERIFY THE PHYSICAL DOOR"or("TEST FAILED: "..tostring(err));drawDetail(e,selected)
        elseif id=="mode_hold"then mode="hold";drawDetail(e,selected)
        elseif id=="mode_invert"then mode="invert";drawDetail(e,selected)
        elseif id=="mode_pulse"then mode="pulse";drawDetail(e,selected)
        elseif id=="pulse_025"then pulseSeconds=.25;drawDetail(e,selected)
        elseif id=="pulse_05"then pulseSeconds=.5;drawDetail(e,selected)
        elseif id=="pulse_10"then pulseSeconds=1;drawDetail(e,selected)
        elseif id=="remove"and selected then
            rawSet(selected,false);local ok,err=pcall(doors.handleCommand,"remove_local",{target=selected.target,side=selected.side});status=ok and"DOOR REMOVED"or("REMOVE FAILED: "..tostring(err));selected=nil;drawList(e)
        elseif id=="save"and selected then
            rawSet(selected,false);local old=configured(selected.target,selected.side);local name,nameErr=readNameTouch(e,old and old.name or"DOOR")
            if not name then status="SAVE CANCELLED: "..tostring(nameErr or"cancelled");drawDetail(e,selected);goto continue end
            if not old then local ok,err=pcall(doors.handleCommand,"register_local",{target=selected.target,side=selected.side,name=name});if not ok then status="SAVE FAILED: "..tostring(err);drawDetail(e,selected);goto continue end end
            local ok,err=pcall(doors.handleCommand,"configure_local",{target=selected.target,side=selected.side,name=name,mode=mode,pulseSeconds=pulseSeconds});status=ok and("SAVED "..upper(name).." - LIVE ON NEXT REFRESH")or("SAVE FAILED: "..tostring(err));drawDetail(e,selected)
        elseif id and id:sub(1,5)=="pick:"then
            local ix=tonumber(id:sub(6));local list=candidates();selected=list[ix or 0];status="";if selected then local old=configured(selected.target,selected.side);mode=old and tostring(old.mode or"hold")or"hold";pulseSeconds=old and tonumber(old.pulseSeconds)or.5;drawDetail(e,selected)end
        end
    end
    ::continue::
end
if selected then pcall(rawSet,selected,false)end
term.setBackgroundColor(colors.black);term.setTextColor(colors.white);term.clear();term.setCursorPos(1,1)
print("[KIMI] door setup closed")
