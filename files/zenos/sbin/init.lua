-- ZenOS init: boot banner, rc scripts, login loop, shell
local term,sh,fs,sched=require("term"),require("sh"),require("fs"),require("sched")
local users=require("users")
local env=sched.current().env

local function rc()
  local dir="/etc/rc.d"
  if not fs.isDir(dir)then return end
  local l=fs.list(dir)
  table.sort(l)
  for _,n in ipairs(l)do
    if n:match("%.lua$")then
      local ok,e=pcall(dofile,dir.."/"..n)
      if not ok then term.write("\27[31mrc: "..n..": "..tostring(e).."\27[0m\n")end
    end
  end
end

term.write(string.format("\27[36m%s %s\27[0m  (%s, %dK RAM)\n",_OSNAME,_OSVERSION,_VERSION,computer.totalMemory()//1024))
rc()
while true do
  local name,home=users.login()
  env.USER=name;env.HOME=home
  if not fs.exists(home)then fs.mkdir(home)end
  env.PWD=fs.isDir(home)and home or"/"
  local ok,e=pcall(dofile,"/etc/profile.lua")
  if not ok then term.write("profile: "..tostring(e).."\n")end
  local motd=fs.readfile("/etc/motd")
  if motd then term.write(motd)end
  sh.interactive()
  term.write("logout\n")
  term.clear()
end
