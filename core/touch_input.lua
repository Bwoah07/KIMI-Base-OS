local M={}

local rows={"1234567890","QWERTYUIOP","ASDFGHJKL","ZXCVBNM-_"}
local function add(boxes,x1,y1,x2,y2,id,label,bg)
    boxes[#boxes+1]={x1=x1,y1=y1,x2=x2,y2=y2,id=id,label=label,bg=bg}
end
local function hit(boxes,x,y)
    for _,b in ipairs(boxes or{}) do if x>=b.x1 and x<=b.x2 and y>=b.y1 and y<=b.y2 then return b end end
end
local function sanitize(v,maxLen)
    v=tostring(v or""):gsub("[^%w _%-]","")
    v=v:gsub("^%s+",""):gsub("%s+$","")
    if maxLen and #v>maxLen then v=v:sub(1,maxLen) end
    return v
end
function M.sanitize(v,maxLen)return sanitize(v,maxLen)end
function M.layout(w,h)
    w,h=tonumber(w)or 0,tonumber(h)or 0
    if w<34 or h<18 then return nil,"monitor too small for touch keyboard" end
    local boxes={};local keyH=h>=24 and 2 or 1;local top=6
    for r,line in ipairs(rows) do
        local count=#line;local keyW=math.max(3,math.floor((w-2)/10));local total=count*keyW;local x0=math.max(1,math.floor((w-total)/2)+1);local y1=top+(r-1)*(keyH+1)
        for i=1,count do local ch=line:sub(i,i);local x1=x0+(i-1)*keyW;add(boxes,x1,y1,math.min(w,x1+keyW-1),y1+keyH-1,"char:"..ch,ch)end
    end
    local y=top+4*(keyH+1)
    local third=math.max(8,math.floor((w-4)/3))
    add(boxes,2,y,1+third,y+1,"space","SPACE")
    add(boxes,3+third,y,2+third*2,y+1,"back","BACK")
    add(boxes,4+third*2,y,w-1,y+1,"clear","CLEAR")
    local y2=math.min(h-1,y+3);local half=math.floor(w/2)
    add(boxes,2,y2,half-1,h,"cancel","CANCEL")
    add(boxes,half+1,y2,w-1,h,"save","SAVE")
    return boxes
end

local function put(e,x,y,text,fg,bg)
    if y<1 or y>e.h or x>e.w then return end
    text=tostring(text or"");e.mon.setCursorPos(math.max(1,x),y);e.mon.setBackgroundColor(bg or colors.black);e.mon.setTextColor(fg or colors.white);e.mon.write(text:sub(1,math.max(0,e.w-x+1)))
end
local function fill(e,x1,y1,x2,y2,bg)
    x1,x2=math.max(1,x1),math.min(e.w,x2);y1,y2=math.max(1,y1),math.min(e.h,y2)
    for y=y1,y2 do put(e,x1,y,string.rep(" ",math.max(0,x2-x1+1)),colors.white,bg)end
end
local function center(e,y,text,fg,bg,x1,x2)
    x1,x2=x1 or 1,x2 or e.w;local width=x2-x1+1;text=tostring(text or"")
    if #text>width then text=text:sub(1,width)end
    put(e,x1+math.max(0,math.floor((width-#text)/2)),y,text,fg,bg)
end
local function draw(e,title,value,boxes,opts)
    e.mon.setBackgroundColor(colors.black);e.mon.setTextColor(colors.white);e.mon.clear()
    put(e,2,1,title or"KIMI TOUCH INPUT",colors.white)
    put(e,2,2,opts.subtitle or"TAP KEYS, THEN SAVE",colors.lightGray)
    fill(e,2,3,e.w-1,4,colors.gray);center(e,3,value==""and"_"or value,colors.white,colors.gray,2,e.w-1)
    for _,b in ipairs(boxes) do
        local bg=(b.id=="save"and colors.lime)or(b.id=="cancel"and colors.red)or colors.gray
        local fg=(b.id=="save"and colors.black)or colors.white
        fill(e,b.x1,b.y1,b.x2,b.y2,bg);center(e,math.floor((b.y1+b.y2)/2),b.label,fg,bg,b.x1,b.x2)
    end
end

function M.read(e,opts)
    opts=opts or{}
    if not e or not e.mon then return nil,false,"monitor unavailable" end
    local boxes,err=M.layout(e.w,e.h);if not boxes then return nil,false,err end
    local maxLen=math.max(1,tonumber(opts.maxLen)or 28);local value=sanitize(opts.value or"",maxLen)
    draw(e,opts.title,value,boxes,opts)
    while true do
        local ev={os.pullEvent()}
        if ev[1]=="terminate" then return nil,false,"cancelled" end
        if ev[1]=="peripheral_detach" and tostring(ev[2])==tostring(e.name) then return nil,false,"monitor detached" end
        if ev[1]=="monitor_touch" and tostring(ev[2])==tostring(e.name) then
            local b=hit(boxes,tonumber(ev[3])or 0,tonumber(ev[4])or 0)
            if b then
                if b.id:sub(1,5)=="char:" then if #value<maxLen then value=value..b.id:sub(6) end
                elseif b.id=="space" then if #value<maxLen and value:sub(-1)~=" " then value=value.." " end
                elseif b.id=="back" then value=value:sub(1,math.max(0,#value-1))
                elseif b.id=="clear" then value=""
                elseif b.id=="cancel" then return nil,false,"cancelled"
                elseif b.id=="save" then
                    value=sanitize(value,maxLen)
                    if value~="" or opts.allowEmpty then return value,true end
                end
                draw(e,opts.title,value,boxes,opts)
            end
        end
    end
end
return M
