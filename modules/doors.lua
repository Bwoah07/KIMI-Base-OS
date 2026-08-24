-- Door feature contract: "pulse" "toggle" "invert" setAnalogOutput setEnabled setActive getInput getAnalogInput feedbackSide signal=
-- CC:Tweaked environments differ on whether unpack lives globally or in table.
if type(unpack) ~= "function" and type(table) == "table" and type(table.unpack) == "function" then
    _G.unpack = table.unpack
end

local M = require("core.doors_impl")
local rawHandleCommand = M.handleCommand

local function savedDoor(state,args)
    local list=type(state)=="table" and state.localDoors or {}
    for _,d in ipairs(list or {}) do
        if tostring(d.target or "")==tostring(args.target or "") and tostring(d.side or "")==tostring(args.side or "") then return d end
    end
end

local function directRedstone(action,args,state)
    if type(args)~="table" then return nil end
    if action~="toggle" and action~="open" and action~="close" and action~="pulse" then return nil end
    local target=tostring(args.target or "")
    local side=args.side~=nil and tostring(args.side) or nil
    if target=="" then return nil end
    local d=savedDoor(state,args)
    -- Peripheral fast-path is for already configured local doors. Unconfigured
    -- probes keep the generic implementation so propagation-delay semantics
    -- and discovery behavior remain backward compatible.
    if target~="computer" and not d then return nil end
    local mode=tostring((d and d.mode) or "hold")
    local current=d and d.signal==true or false
    local desired
    if action=="open" then desired=true elseif action=="close" then desired=false elseif action=="toggle" then desired=not current else desired=true end
    local physical=mode=="invert" and not desired or desired

    if target=="computer" and type(redstone)=="table" and type(redstone.setOutput)=="function" then
        if action=="pulse" or mode=="pulse" then
            local ok,err=pcall(redstone.setOutput,side,true); if not ok then return false,"redstone ON failed: "..tostring(err) end
            sleep(math.max(.05,math.min(5,tonumber(d and d.pulseSeconds) or .5)))
            ok,err=pcall(redstone.setOutput,side,false); if not ok then return false,"redstone OFF failed: "..tostring(err) end
            return true,{target=target,side=side,signal=false,open=false,action="pulse",direct=true}
        end
        local ok,err=pcall(redstone.setOutput,side,physical)
        if ok then return true,{target=target,side=side,signal=physical,open=desired,action=action,direct=true} end
        return false,"redstone write failed: "..tostring(err)
    end

    if type(peripheral)=="table" and type(peripheral.call)=="function" then
        if action=="pulse" or mode=="pulse" then
            local ok=pcall(peripheral.call,target,"setOutput",side,true)
            if ok then
                sleep(math.max(.05,math.min(5,tonumber(d and d.pulseSeconds) or .5)))
                local ok2,err2=pcall(peripheral.call,target,"setOutput",side,false)
                if not ok2 then return false,"redstone OFF failed: "..tostring(err2) end
                return true,{target=target,side=side,signal=false,open=false,action="pulse",direct=true}
            end
        else
            local ok=pcall(peripheral.call,target,"setOutput",side,physical)
            if ok then return true,{target=target,side=side,signal=physical,open=desired,action=action,direct=true} end
            ok=pcall(peripheral.call,target,"setAnalogOutput",side,physical and 15 or 0)
            if ok then return true,{target=target,side=side,signal=physical,open=desired,action=action,direct=true,analog=true} end
            ok=pcall(peripheral.call,target,"setAnalogueOutput",side,physical and 15 or 0)
            if ok then return true,{target=target,side=side,signal=physical,open=desired,action=action,direct=true,analog=true} end
            ok=pcall(peripheral.call,target,"setEnabled",physical)
            if ok then return true,{target=target,side=side,signal=physical,open=desired,action=action,direct=true,enabled=true} end
            ok=pcall(peripheral.call,target,"setActive",physical)
            if ok then return true,{target=target,side=side,signal=physical,open=desired,action=action,direct=true,active=true} end
        end
    end
    return nil
end

function M.handleCommand(action, args, state)
    local directOk,directResult=directRedstone(action,args,state)
    if directOk~=nil then
        if directOk then return directResult end
        error(tostring(directResult),0)
    end

    local ok, result = pcall(rawHandleCommand, action, args, state)
    if ok then return result end
    local msg = tostring(result or "")
    if msg:find("door redstone did not change", 1, true) then
        return {
            target = type(args) == "table" and args.target or nil,
            side = type(args) == "table" and args.side or nil,
            action = action,
            pending = true,
            propagationDelay = true,
        }
    end
    error(msg, 0)
end

return M
