local M={}

local function readFile(path)
    if not fs.exists(path)or fs.isDir(path)then return nil end
    local f=fs.open(path,"r");if not f then return nil end
    local body=f.readAll();f.close();return body
end

local function version()
    return tostring((readFile("version.txt")or"unknown"):gsub("%s+$",""))
end

local function friendlyName(cfg)
    local label=type(os.getComputerLabel)=="function"and os.getComputerLabel()or nil
    if label and tostring(label):match("%S")then return tostring(label)end
    return tostring(cfg and cfg.name or("KIMI-"..tostring(os.getComputerID())))
end

function M.newSession(role)
    local now=type(os.epoch)=="function"and os.epoch("utc")or math.floor((tonumber(os.time())or 0)*1000)
    return table.concat({tostring(role or"kimi"),tostring(os.getComputerID()),tostring(now)},":")
end

function M.snapshot(cfg,role,profile,sessionId)
    return{
        sourceId=os.getComputerID(),computerId=os.getComputerID(),
        role=tostring(role or"client"),profile=tostring(profile or cfg and cfg.profile or"?"),
        name=friendlyName(cfg),version=version(),sessionId=tostring(sessionId or""),
        verifiedAt=type(os.epoch)=="function"and os.epoch("utc")or math.floor((tonumber(os.time())or 0)*1000),
    }
end

return M
