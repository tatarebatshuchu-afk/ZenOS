-- label [path] [new label]
local fs=require("fs")
local path,new=...
path=path or"/"
local px=fs.proxyOf(path)
if new then px.setLabel(new)else print(px.getLabel()or"(none)")end
