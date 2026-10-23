local n=...
if not n then print(os.getenv("HOSTNAME")or"zen")return end
require("fs").writefile("/etc/hostname",n.."\n")
os.setenv("HOSTNAME",n)
