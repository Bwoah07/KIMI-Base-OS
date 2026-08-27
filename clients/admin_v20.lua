local base=require("clients.admin_v19")
local M={}
for k,v in pairs(base)do M[k]=v end
function M.init(c)
 local real=os.startTimer
 if type(real)~="function"then os.startTimer=function()return -7300 end end
 local ok,res=pcall(base.init,c)
 if type(real)~="function"then os.startTimer=nil end
 if not ok then error(res,0)end
 return res
end
return M
