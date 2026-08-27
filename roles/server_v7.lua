-- Alpha79: keep Main Base responsive while heavy telemetry exists.
-- The server UI/event loop still refreshes quickly, but AE2/Flux/Matrix/
-- attachments/Builder are sampled on a slower lane so rednet heartbeats and
-- commands are not starved by expensive peripheral calls.
local base=require("roles.server_v6")
local loader=require("core.module_loader")
local M={}

local HEAVY_MS=5000
local heavyIds={attachments=true,power=true,power_reserve=true,ae2=true,builder=true}

local function now()
    local ok,v=pcall(os.epoch,"utc")
    return ok and tonumber(v) or 0
end

function M.run(cfg)
    local realReadAll=loader.readAll
    local lastHeavy=-math.huge

    loader.readAll=function(modules,previous)
        modules=modules or{}
        previous=previous or{}
        local fast,heavy={},{}
        for id,module in pairs(modules)do
            if heavyIds[id]then heavy[id]=module else fast[id]=module end
        end

        local out=realReadAll(fast,previous)or{}
        local t=now()
        if t-lastHeavy>=HEAVY_MS then
            local sampled=realReadAll(heavy,previous)or{}
            for id,value in pairs(sampled)do out[id]=value end
            lastHeavy=t
        else
            for id in pairs(heavyIds)do
                if previous[id]~=nil then out[id]=previous[id]end
            end
        end
        return out
    end

    local ok,res=xpcall(function()return base.run(cfg)end,function(err)return err end)
    loader.readAll=realReadAll
    if not ok then error(res,0)end
    return res
end

return M
