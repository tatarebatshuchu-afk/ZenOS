local a={...}
local nl=true
if a[1]=="-n"then nl=false;table.remove(a,1)end
io.write(table.concat(a," "),nl and"\n"or"")
