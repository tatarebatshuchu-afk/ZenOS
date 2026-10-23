local fs,args,text=require("fs"),require("args"),require("text")
local o,p=args.parse({...},{n=true})
local n=tonumber(o.n)or 10
local d=p[1]and fs.readfile(p[1])or io.read("a")or""
local l=text.lines(d)
for i=1,math.min(n,#l)do print(l[i])end
