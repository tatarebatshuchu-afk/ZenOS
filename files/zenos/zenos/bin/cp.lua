local fs,args=require("fs"),require("args")
local o,p=args.parse({...})
if#p<2 then io.stderr:write("usage: cp [-r] src... dest\n")return 1 end
local dest=table.remove(p)
local isdir=fs.isDir(dest)
if#p>1 and not isdir then io.stderr:write("cp: target is not a directory\n")return 1 end
local rc=0
for _,s in ipairs(p)do
  if not fs.exists(s)then io.stderr:write("cp: "..s..": no such file\n");rc=1
  elseif fs.isDir(s)and not(o.r or o.R)then io.stderr:write("cp: "..s..": is a directory (use -r)\n");rc=1
  else
    local ok,e=fs.copy(s,isdir and fs.concat(dest,fs.name(s))or dest)
    if not ok then io.stderr:write("cp: "..tostring(e).."\n");rc=1 end
  end
end
return rc
