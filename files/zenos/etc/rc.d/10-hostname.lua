-- Applies /etc/hostname to the init environment
local fs=require("fs")
local h=(fs.readfile("/etc/hostname")or""):match("%S+")
if h then os.setenv("HOSTNAME",h)end
