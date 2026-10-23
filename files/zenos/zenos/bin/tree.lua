local fs=require("fs")
local function walk(path,prefix)
  local l=fs.list(path)
  table.sort(l)
  for i,n in ipairs(l)do
    local last=i==#l
    print(prefix..(last and"└── "or"├── ")..n)
    if n:sub(-1)=="/"then walk(fs.concat(path,n),prefix..(last and"    "or"│   "))end
  end
end
local root=...or"."
print(root)
walk(root,"")
