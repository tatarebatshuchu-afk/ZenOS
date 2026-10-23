-- Ctrl+<letter> detection (control character OR ctrl modifier state + scancode)
local sched=require("sched")
local K={}
local map={a={1,30},c={3,46},d={4,32},e={5,18},k={11,37},l={12,38},q={17,16},s={19,31},u={21,22}}
function K.ctrl(ch,code,n)
  local m=map[n]
  return ch==m[1]or(sched.ctrl and code==m[2])or false
end
return K
