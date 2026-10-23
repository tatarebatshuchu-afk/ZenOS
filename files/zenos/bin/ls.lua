local fs,args,term,text=require("fs"),require("args"),require("term"),require("text")
local o,p=args.parse({...})
if#p==0 then p[1]="."end
local W=term.size()
local tty=term.isatty()
local BL,RS=tty and"\27[34m"or"",tty and"\27[0m"or""
local function show(base,names)
  table.sort(names)
  local out={}
  for _,n in ipairs(names)do if o.a or n:sub(1,1)~="."then out[#out+1]=n end end
  if o.l then
    for _,n in ipairs(out)do
      local d=n:sub(-1)=="/"
      local sz=d and"-"or text.size(fs.size(fs.concat(base,n)))
      io.write(string.format("%s %7s  %s%s%s\n",d and"d"or"-",sz,d and BL or"",n,RS))
    end
  elseif not tty then
    for _,n in ipairs(out)do print(n)end
  else
    local mx=0
    for _,n in ipairs(out)do mx=math.max(mx,unicode.len(n))end
    local cw=mx+2
    local cols=math.max(1,W//cw)
    for i,n in ipairs(out)do
      io.write((n:sub(-1)=="/"and BL or"")..n..RS..string.rep(" ",cw-unicode.len(n)))
      if i%cols==0 then io.write("\n")end
    end
    if#out%cols~=0 then io.write("\n")end
  end
end
local rc=0
for _,path in ipairs(p)do
  if not fs.exists(path)then io.stderr:write("ls: "..path..": no such file or directory\n");rc=1
  elseif fs.isDir(path)then
    if#p>1 then print(path..":")end
    show(path,fs.list(path))
  else print(path)end
end
return rc
