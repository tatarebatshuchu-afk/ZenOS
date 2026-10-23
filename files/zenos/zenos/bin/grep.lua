local fs,args,text=require("fs"),require("args"),require("text")
local o,p=args.parse({...})
local pat=table.remove(p,1)
if not pat then io.stderr:write("usage: grep [-ivnF] pattern [file...]  (Lua patterns)\n")return 2 end
if o.i then pat=pat:lower()end
local found=false
local function scan(d,name)
  for n,l in ipairs(text.lines(d))do
    local s=o.i and l:lower()or l
    local m=s:find(pat,1,o.F and true or false)~=nil
    if o.v then m=not m end
    if m then
      found=true
      io.write((name and name..":"or"")..(o.n and n..":"or"")..l.."\n")
    end
  end
end
if#p==0 then scan(io.read("a")or"")
else
  for _,f in ipairs(p)do
    local d=fs.readfile(f)
    if d then scan(d,#p>1 and f or nil)else io.stderr:write("grep: "..f..": cannot read\n")end
  end
end
return found and 0 or 1
