local term=require("term")
local env=setmetatable({},{__index=_G})
print(_VERSION.." REPL - 'exit' or Ctrl+D to quit")
while true do
  local l=term.read("lua> ")
  if not l or l=="exit"then break end
  if l:match("%S")then
    local f,e=load("return "..l,"=stdin","t",env)
    if not f then f,e=load(l,"=stdin","t",env)end
    if f then
      local r=table.pack(pcall(f))
      if r[1]then
        for i=2,r.n do io.write(tostring(r[i]),i<r.n and"\t"or"\n")end
      else io.stderr:write(tostring(r[2]).."\n")end
    else io.stderr:write(tostring(e).."\n")end
  end
end
