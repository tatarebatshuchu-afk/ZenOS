-- find [dir] ['mask']   e.g. find / '*.lua'
local fs,args=require("fs"),require("args")
local _,p=args.parse({...})
local root,mask=p[1]or".",p[2]
local lp
if mask then lp="^"..mask:gsub("[%^%$%(%)%%%.%[%]%+%-]","%%%0"):gsub("%*",".*"):gsub("%?",".").."$"end
local function walk(dir)
  for _,n in ipairs(fs.list(dir))do
    local nn=n:gsub("/$","")
    local full=fs.concat(dir,nn)
    if not lp or nn:match(lp)then print(full)end
    if n:sub(-1)=="/"then walk(full)end
  end
end
walk(root)
