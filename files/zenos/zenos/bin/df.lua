local fs,text=require("fs"),require("text")
print(string.format("%-10s %-12s %8s %8s",  "Mount","Label","Used","Total"))
for _,m in ipairs(fs.mounts())do
  local px=m.proxy
  print(string.format("%-10s %-12s %8s %8s",m.path,px.getLabel()or"-",text.size(px.spaceUsed()),text.size(px.spaceTotal())))
end
