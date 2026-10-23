local fs,term,sched,text=require("fs"),require("term"),require("sched"),require("text")
local f=...
local d
if f then
  d=fs.readfile(f)
  if not d then io.stderr:write("more: cannot read "..f.."\n")return 1 end
else d=io.read("a")or""end
local _,H=term.size()
local n=0
sched.setraw(true)
for _,l in ipairs(text.lines(d))do
  print(l)
  n=n+1
  if n>=H-1 then
    io.write("\27[7m-- more (space: page, enter: line, q: quit) --\27[0m")
    local _,_,ch=sched.pull("key_down")
    io.write("\r\27[K")
    if ch==113 then break end
    n=(ch==32)and 0 or H-2
  end
end
sched.setraw(false)
