local term=require("term")
local w,h=tonumber((...)),tonumber((select(2,...)))
if not w or not h then
  local cw,ch=term.size()
  local mw,mh=term.gpu().maxResolution()
  print("current "..cw.."x"..ch..", max "..mw.."x"..mh.."   usage: resolution <w> <h>")
  return
end
term.setResolution(w,h)
