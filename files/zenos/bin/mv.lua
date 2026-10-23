local fs=require("fs")
local p={...}
if#p<2 then io.stderr:write("usage: mv src... dest\n")return 1 end
local dest=table.remove(p)
local isdir=fs.isDir(dest)
if#p>1 and not isdir then io.stderr:write("mv: target is not a directory\n")return 1 end
local rc=0
for _,s in ipairs(p)do
  local ok,e=fs.rename(s,isdir and fs.concat(dest,fs.name(s))or dest)
  if not ok then io.stderr:write("mv: "..s..": "..tostring(e or"failed").."\n");rc=1 end
end
return rc
