local fs=require("fs")
local files={...}
if#files==0 then io.write(io.read("a")or"")return 0 end
local rc=0
for _,f in ipairs(files)do
  local d,e=fs.readfile(f)
  if d then io.write(d)else io.stderr:write("cat: "..f..": "..tostring(e).."\n");rc=1 end
end
return rc
