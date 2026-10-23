local fs=require("fs")
for _,f in ipairs{...}do if not fs.exists(f)then fs.writefile(f,"")end end
