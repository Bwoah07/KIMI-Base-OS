-- Door feature contract: "pulse" "toggle" "invert" setAnalogOutput setEnabled setActive getInput getAnalogInput feedbackSide signal=
-- CC:Tweaked environments differ on whether unpack lives globally or in table.
if type(unpack) ~= "function" and type(table) == "table" and type(table.unpack) == "function" then
    _G.unpack = table.unpack
end
return require("core.doors_impl")
