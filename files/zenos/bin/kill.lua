local sched=require("sched")
for _,a in ipairs{...}do
  if not sched.kill(tonumber(a))then io.stderr:write("kill: no such process "..a.."\n")end
end
