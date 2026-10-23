-- mount [addr-prefix [dir]]
local fs=require("fs")
local a,b=...
if not a then
  for _,m in ipairs(fs.mounts())do print(m.path.."  "..m.proxy.address)end
  return 0
end
local found
for addr in component.list("filesystem")do
  if addr:sub(1,#a)==a then found=addr;break end
end
if not found then io.stderr:write("mount: no such device\n")return 1 end
local ok,e=fs.mount(b or"/mnt/"..a,found)
if not ok then io.stderr:write("mount: "..tostring(e).."\n")return 1 end
