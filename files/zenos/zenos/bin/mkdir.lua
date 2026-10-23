local fs=require("fs")
local rc=0
for _,d in ipairs{...}do
  if d:sub(1,1)~="-"then
    if not fs.mkdir(d)then io.stderr:write("mkdir: cannot create "..d.."\n");rc=1 end
  end
end
return rc
