local fs=require("fs")
local function count(d)
  local _,l=d:gsub("\n","")
  local _,w=d:gsub("%S+","")
  return l,w,#d
end
local f={...}
if#f==0 then print(count(io.read("a")or""))return 0 end
for _,n in ipairs(f)do
  local d=fs.readfile(n)
  if d then print(table.concat({count(d)},"\t").."\t"..n)else io.stderr:write("wc: "..n..": cannot read\n")end
end
