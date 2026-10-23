-- wget <url> [file|-]
local fs=require("fs")
local url,path=...
if not url then io.stderr:write("usage: wget <url> [file|-]\n")return 1 end
path=path or url:match("([^/]+)$")or"index.html"
local inet=component.list("internet")()
if not inet then io.stderr:write("wget: no internet card\n")return 1 end
local ok,h=pcall(component.invoke,inet,"request",url)
if not ok or not h then io.stderr:write("wget: "..tostring(h).."\n")return 1 end
local out
if path~="-"then
  local e
  out,e=fs.open(path,"w")
  if not out then io.stderr:write("wget: "..tostring(e).."\n")return 1 end
end
local total=0
while true do
  local s,e=h.read()
  if not s then
    if e then io.stderr:write("wget: "..tostring(e).."\n")end
    break
  end
  if s==""then os.sleep(0.05)
  else
    total=total+#s
    if out then out:write(s)else io.write(s)end
  end
end
h.close()
if out then out:close();print(path..": "..total.." bytes")end
