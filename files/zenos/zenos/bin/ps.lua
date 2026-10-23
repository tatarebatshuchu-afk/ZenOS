local sched=require("sched")
print("PID  PPID  UP(s)  NAME")
for _,p in ipairs(sched.list())do
  print(string.format("%-4d %-5s %-6d %s",p.pid,tostring(p.parent or"-"),math.floor(computer.uptime()-p.start),p.name))
end
