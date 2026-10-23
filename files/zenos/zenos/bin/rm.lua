local fs,args=require("fs"),require("args")
local o,p=args.parse({...})
local rc=0
for _,f in ipairs(p)do
  if not fs.exists(f)then io.stderr:write("rm: "..f..": no such file\n");rc=1
  elseif fs.canonical(f)=="/"then io.stderr:write("rm: refusing to remove /\n");rc=1
  elseif fs.isDir(f)and not(o.r or o.R)then io.stderr:write("rm: "..f..": is a directory (use -r)\n");rc=1
  else fs.remove(f)end
end
return rc
