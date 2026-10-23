-- ZenOS 1.0 self-extracting installer (run in OpenOS or ZenOS)
local files={
{"/bin/beep.lua",[[
local f,d=...
computer.beep(tonumber(f)or 800,tonumber(d)or 0.2)
]]},
{"/bin/cat.lua",[[
local fs=require("fs")
local files={...}
if#files==0 then io.write(io.read("a")or"")return 0 end
local rc=0
for _,f in ipairs(files)do
  local d,e=fs.readfile(f)
  if d then io.write(d)else io.stderr:write("cat: "..f..": "..tostring(e).."\n");rc=1 end
end
return rc
]]},
{"/bin/clear.lua",[[
require("term").clear()
]]},
{"/bin/components.lua",[[
for a,t in component.list((...))do print(a.."  "..t)end
]]},
{"/bin/cp.lua",[[
local fs,args=require("fs"),require("args")
local o,p=args.parse({...})
if#p<2 then io.stderr:write("usage: cp [-r] src... dest\n")return 1 end
local dest=table.remove(p)
local isdir=fs.isDir(dest)
if#p>1 and not isdir then io.stderr:write("cp: target is not a directory\n")return 1 end
local rc=0
for _,s in ipairs(p)do
  if not fs.exists(s)then io.stderr:write("cp: "..s..": no such file\n");rc=1
  elseif fs.isDir(s)and not(o.r or o.R)then io.stderr:write("cp: "..s..": is a directory (use -r)\n");rc=1
  else
    local ok,e=fs.copy(s,isdir and fs.concat(dest,fs.name(s))or dest)
    if not ok then io.stderr:write("cp: "..tostring(e).."\n");rc=1 end
  end
end
return rc
]]},
{"/bin/date.lua",[[
print(os.date("%Y-%m-%d %H:%M:%S"))
]]},
{"/bin/df.lua",[[
local fs,text=require("fs"),require("text")
print(string.format("%-10s %-12s %8s %8s",  "Mount","Label","Used","Total"))
for _,m in ipairs(fs.mounts())do
  local px=m.proxy
  print(string.format("%-10s %-12s %8s %8s",m.path,px.getLabel()or"-",text.size(px.spaceUsed()),text.size(px.spaceTotal())))
end
]]},
{"/bin/echo.lua",[[
local a={...}
local nl=true
if a[1]=="-n"then nl=false;table.remove(a,1)end
io.write(table.concat(a," "),nl and"\n"or"")
]]},
{"/bin/edit.lua",[[
-- edit <file>: arrows, Home/End, PgUp/PgDn, Ctrl+S save, Ctrl+Q quit
local fs,term,sched,keys=require("fs"),require("term"),require("sched"),require("keys")
local path=...
if not path then io.stderr:write("usage: edit <file>\n")return 1 end
path=fs.canonical(path)
local lines={""}
if fs.exists(path)then
  local d=fs.readfile(path)or""
  lines={}
  for l in(d:gsub("\n$","").."\n"):gmatch("(.-)\n")do lines[#lines+1]=(l:gsub("\t","  "))end
end
local gpu=term.gpu()
local W,H=term.size()
local VH=H-1
local cx,cy,top,left=1,1,1,0
local modified,msg,quitwarn=false,"Ctrl+S save  Ctrl+Q quit",false

local function draw()
  if cy<top then top=cy elseif cy>=top+VH then top=cy-VH+1 end
  if cx-1<left then left=cx-1 elseif cx-1>=left+W then left=cx-W end
  gpu.setBackground(0);gpu.setForeground(0xCCCCCC)
  for r=1,VH do
    local l=lines[top+r-1]
    gpu.fill(1,r,W,1," ")
    if l then
      local s=unicode.sub(l,left+1,left+W)
      if s~=""then gpu.set(1,r,s)end
    end
  end
  gpu.setBackground(0xCCCCCC);gpu.setForeground(0)
  local st=string.format(" %s%s  Ln %d/%d Col %d  %s",fs.name(path),modified and"*"or"",cy,#lines,cx,msg)
  gpu.fill(1,H,W,1," ")
  gpu.set(1,H,unicode.sub(st,1,W))
  local ch=unicode.sub(lines[cy],cx,cx)
  if ch==""then ch=" "end
  gpu.set(cx-left,cy-top+1,ch)
  gpu.setBackground(0);gpu.setForeground(0xCCCCCC)
end

local function save()
  local ok,e=fs.writefile(path,table.concat(lines,"\n").."\n")
  if ok then modified=false;msg="saved"else msg="save failed: "..tostring(e)end
end

sched.setraw(true)
local running=true
while running do
  draw()
  local e,_,ch,code=sched.pull("key_down")
  local l=lines[cy]
  local n=unicode.len(l)
  local wasq=quitwarn
  quitwarn=false
  msg=""
  if code==200 then cy=math.max(1,cy-1)
  elseif code==208 then cy=math.min(#lines,cy+1)
  elseif code==203 then
    if cx>1 then cx=cx-1 elseif cy>1 then cy=cy-1;cx=unicode.len(lines[cy])+1 end
  elseif code==205 then
    if cx<=n then cx=cx+1 elseif cy<#lines then cy=cy+1;cx=1 end
  elseif code==199 then cx=1
  elseif code==207 then cx=n+1
  elseif code==201 then cy=math.max(1,cy-VH)
  elseif code==209 then cy=math.min(#lines,cy+VH)
  elseif code==28 or code==156 then
    local ind=l:match("^%s*")
    table.insert(lines,cy+1,ind..unicode.sub(l,cx))
    lines[cy]=unicode.sub(l,1,cx-1)
    cy=cy+1;cx=#ind+1;modified=true
  elseif code==14 then
    if cx>1 then
      lines[cy]=unicode.sub(l,1,cx-2)..unicode.sub(l,cx);cx=cx-1;modified=true
    elseif cy>1 then
      cx=unicode.len(lines[cy-1])+1
      lines[cy-1]=lines[cy-1]..l
      table.remove(lines,cy);cy=cy-1;modified=true
    end
  elseif code==211 then
    if cx<=n then lines[cy]=unicode.sub(l,1,cx-1)..unicode.sub(l,cx+1);modified=true
    elseif cy<#lines then lines[cy]=l..lines[cy+1];table.remove(lines,cy+1);modified=true end
  elseif code==15 then
    lines[cy]=unicode.sub(l,1,cx-1).."  "..unicode.sub(l,cx);cx=cx+2;modified=true
  elseif keys.ctrl(ch,code,"s")then save()
  elseif keys.ctrl(ch,code,"q")then
    if modified and not wasq then quitwarn=true;msg="Unsaved changes! Ctrl+Q again to discard"
    else running=false end
  elseif ch>=32 and ch~=127 and not sched.ctrl then
    lines[cy]=unicode.sub(l,1,cx-1)..unicode.char(ch)..unicode.sub(l,cx)
    cx=cx+1;modified=true
  end
  cx=math.min(cx,unicode.len(lines[cy])+1)
end
sched.setraw(false)
term.clear()
]]},
{"/bin/find.lua",[[
-- find [dir] ['mask']   e.g. find / '*.lua'
local fs,args=require("fs"),require("args")
local _,p=args.parse({...})
local root,mask=p[1]or".",p[2]
local lp
if mask then lp="^"..mask:gsub("[%^%$%(%)%%%.%[%]%+%-]","%%%0"):gsub("%*",".*"):gsub("%?",".").."$"end
local function walk(dir)
  for _,n in ipairs(fs.list(dir))do
    local nn=n:gsub("/$","")
    local full=fs.concat(dir,nn)
    if not lp or nn:match(lp)then print(full)end
    if n:sub(-1)=="/"then walk(full)end
  end
end
walk(root)
]]},
{"/bin/flash.lua",[[
-- flash [file]       write BIOS to EEPROM (default /boot/bios.lua)
-- flash -r [file]    dump the current EEPROM code to a file
local fs,args=require("fs"),require("args")
local o,p=args.parse({...})
local ee=component.list("eeprom")()
if not ee then io.stderr:write("flash: no EEPROM\n")return 1 end
local e=component.proxy(ee)
if o.r then
  local path=p[1]or"bios_dump.lua"
  fs.writefile(path,e.get())
  print("saved to "..path)
  return 0
end
local path=p[1]or"/boot/bios.lua"
local d,err=fs.readfile(path)
if not d then io.stderr:write("flash: "..tostring(err).."\n")return 1 end
if#d>e.getSize()then io.stderr:write("flash: file too big ("..#d.." > "..e.getSize()..")\n")return 1 end
io.write("Flash "..path.." ("..#d.." bytes) to EEPROM? [y/N] ")
if io.read()~="y"then print("aborted")return 1 end
e.set(d)
e.setLabel("ZenBIOS")
print("done - reboot to apply")
]]},
{"/bin/free.lua",[[
local text=require("text")
local t,f=computer.totalMemory(),computer.freeMemory()
print("RAM:    "..text.size(t-f).." used / "..text.size(t))
print(string.format("Energy: %d / %d",math.floor(computer.energy()),math.floor(computer.maxEnergy())))
]]},
{"/bin/grep.lua",[[
local fs,args,text=require("fs"),require("args"),require("text")
local o,p=args.parse({...})
local pat=table.remove(p,1)
if not pat then io.stderr:write("usage: grep [-ivnF] pattern [file...]  (Lua patterns)\n")return 2 end
if o.i then pat=pat:lower()end
local found=false
local function scan(d,name)
  for n,l in ipairs(text.lines(d))do
    local s=o.i and l:lower()or l
    local m=s:find(pat,1,o.F and true or false)~=nil
    if o.v then m=not m end
    if m then
      found=true
      io.write((name and name..":"or"")..(o.n and n..":"or"")..l.."\n")
    end
  end
end
if#p==0 then scan(io.read("a")or"")
else
  for _,f in ipairs(p)do
    local d=fs.readfile(f)
    if d then scan(d,#p>1 and f or nil)else io.stderr:write("grep: "..f..": cannot read\n")end
  end
end
return found and 0 or 1
]]},
{"/bin/head.lua",[[
local fs,args,text=require("fs"),require("args"),require("text")
local o,p=args.parse({...},{n=true})
local n=tonumber(o.n)or 10
local d=p[1]and fs.readfile(p[1])or io.read("a")or""
local l=text.lines(d)
for i=1,math.min(n,#l)do print(l[i])end
]]},
{"/bin/help.lua",[[
local cmds={
{"ls [-la] [dir]","list files"},{"cd, pwd","change / show directory"},
{"cat, more, head, tail, wc","view files (more: pager)"},{"edit <file>","text editor (Ctrl+S save, Ctrl+Q quit)"},
{"cp [-r], mv, rm [-r]","copy, move, delete"},{"mkdir, touch","create dir / file"},
{"find [dir] 'mask'","search files by name"},{"grep [-ivnF] pat [f]","search text (Lua patterns)"},
{"tree [dir]","directory tree"},{"df, free, uptime","disk / memory / uptime"},
{"sysinfo","system information"},{"ps, kill <pid>","processes"},
{"components [type]","list OC components"},{"lua","Lua REPL"},
{"wget <url> [file]","download (internet card)"},{"mount, umount, label","filesystems"},
{"flash [-r] [file]","write / dump EEPROM BIOS"},{"install","install ZenOS to another disk"},
{"passwd [user]","set password (enables login)"},{"hostname, whoami, date","misc"},
{"resolution [w h]","screen resolution"},{"alias, export, set, history","shell"},
{"reboot, shutdown","power"},
}
print("ZenOS shell: | > >> < && || ; & * ? \"quotes\" $VAR, Tab completion, Ctrl+C/D")
for _,c in ipairs(cmds)do print(string.format("  %-26s %s",c[1],c[2]))end
]]},
{"/bin/hostname.lua",[[
local n=...
if not n then print(os.getenv("HOSTNAME")or"zen")return end
require("fs").writefile("/etc/hostname",n.."\n")
os.setenv("HOSTNAME",n)
]]},
{"/bin/install.lua",[[
-- install: copy the running ZenOS to another disk and (optionally) flash ZenBIOS
local fs,text=require("fs"),require("text")
local boot=computer.getBootAddress()
local list={}
for a in component.list("filesystem")do
  if a~=boot and a~=computer.tmpAddress()then
    local px=component.proxy(a)
    if not px.isReadOnly()then list[#list+1]=px end
  end
end
if#list==0 then io.stderr:write("no writable target disks found\n")return 1 end
for i,px in ipairs(list)do
  print(i..") "..px.address:sub(1,8).."  "..(px.getLabel()or"-").."  "..text.size(px.spaceTotal()))
end
io.write("Target disk number: ")
local px=list[tonumber(io.read())or 0]
if not px then print("cancelled")return 1 end
io.write("ZenOS files on "..px.address:sub(1,8).." will be overwritten. Continue? [y/N] ")
if io.read()~="y"then print("cancelled")return 1 end
local mp="/mnt/"..px.address:sub(1,3)
fs.mount(mp,px)
for _,d in ipairs{"bin","lib","sbin","etc","boot","usr"}do
  if fs.exists("/"..d)then
    print("copying /"..d)
    local ok,e=fs.copy("/"..d,mp.."/"..d)
    if not ok then io.stderr:write("error: "..tostring(e).."\n")return 1 end
  end
end
for _,d in ipairs{"home","mnt","tmp"}do fs.mkdir(mp.."/"..d)end
fs.copy("/init.lua",mp.."/init.lua")
io.write("Flash ZenBIOS to EEPROM? [Y/n] ")
local a=io.read()
if a~="n"and a~="N"then
  local ee=component.list("eeprom")()
  local bios=fs.readfile("/boot/bios.lua")
  if ee and bios then
    local e=component.proxy(ee)
    e.set(bios);e.setLabel("ZenBIOS")
    computer.setBootAddress(px.address)
    print("BIOS flashed")
  else print("no EEPROM or /boot/bios.lua missing")end
end
print("Done. Reboot to start from the new disk.")
]]},
{"/bin/kill.lua",[[
local sched=require("sched")
for _,a in ipairs{...}do
  if not sched.kill(tonumber(a))then io.stderr:write("kill: no such process "..a.."\n")end
end
]]},
{"/bin/label.lua",[[
-- label [path] [new label]
local fs=require("fs")
local path,new=...
path=path or"/"
local px=fs.proxyOf(path)
if new then px.setLabel(new)else print(px.getLabel()or"(none)")end
]]},
{"/bin/ls.lua",[[
local fs,args,term,text=require("fs"),require("args"),require("term"),require("text")
local o,p=args.parse({...})
if#p==0 then p[1]="."end
local W=term.size()
local tty=term.isatty()
local BL,RS=tty and"\27[34m"or"",tty and"\27[0m"or""
local function show(base,names)
  table.sort(names)
  local out={}
  for _,n in ipairs(names)do if o.a or n:sub(1,1)~="."then out[#out+1]=n end end
  if o.l then
    for _,n in ipairs(out)do
      local d=n:sub(-1)=="/"
      local sz=d and"-"or text.size(fs.size(fs.concat(base,n)))
      io.write(string.format("%s %7s  %s%s%s\n",d and"d"or"-",sz,d and BL or"",n,RS))
    end
  elseif not tty then
    for _,n in ipairs(out)do print(n)end
  else
    local mx=0
    for _,n in ipairs(out)do mx=math.max(mx,unicode.len(n))end
    local cw=mx+2
    local cols=math.max(1,W//cw)
    for i,n in ipairs(out)do
      io.write((n:sub(-1)=="/"and BL or"")..n..RS..string.rep(" ",cw-unicode.len(n)))
      if i%cols==0 then io.write("\n")end
    end
    if#out%cols~=0 then io.write("\n")end
  end
end
local rc=0
for _,path in ipairs(p)do
  if not fs.exists(path)then io.stderr:write("ls: "..path..": no such file or directory\n");rc=1
  elseif fs.isDir(path)then
    if#p>1 then print(path..":")end
    show(path,fs.list(path))
  else print(path)end
end
return rc
]]},
{"/bin/lua.lua",[[
local term=require("term")
local env=setmetatable({},{__index=_G})
print(_VERSION.." REPL - 'exit' or Ctrl+D to quit")
while true do
  local l=term.read("lua> ")
  if not l or l=="exit"then break end
  if l:match("%S")then
    local f,e=load("return "..l,"=stdin","t",env)
    if not f then f,e=load(l,"=stdin","t",env)end
    if f then
      local r=table.pack(pcall(f))
      if r[1]then
        for i=2,r.n do io.write(tostring(r[i]),i<r.n and"\t"or"\n")end
      else io.stderr:write(tostring(r[2]).."\n")end
    else io.stderr:write(tostring(e).."\n")end
  end
end
]]},
{"/bin/mkdir.lua",[[
local fs=require("fs")
local rc=0
for _,d in ipairs{...}do
  if d:sub(1,1)~="-"then
    if not fs.mkdir(d)then io.stderr:write("mkdir: cannot create "..d.."\n");rc=1 end
  end
end
return rc
]]},
{"/bin/more.lua",[[
local fs,term,sched,text=require("fs"),require("term"),require("sched"),require("text")
local f=...
local d
if f then
  d=fs.readfile(f)
  if not d then io.stderr:write("more: cannot read "..f.."\n")return 1 end
else d=io.read("a")or""end
local _,H=term.size()
local n=0
sched.setraw(true)
for _,l in ipairs(text.lines(d))do
  print(l)
  n=n+1
  if n>=H-1 then
    io.write("\27[7m-- more (space: page, enter: line, q: quit) --\27[0m")
    local _,_,ch=sched.pull("key_down")
    io.write("\r\27[K")
    if ch==113 then break end
    n=(ch==32)and 0 or H-2
  end
end
sched.setraw(false)
]]},
{"/bin/mount.lua",[=[
-- mount [addr-prefix [dir]]
local fs=require("fs")
local a,b=...
if not a then
  for _,m in ipairs(fs.mounts())do print(m.path.."  "..m.proxy.address)end
  return 0
end
local found
for addr in component.list("filesystem")do
  if addr:sub(1,#a)==a then found=addr;break end
end
if not found then io.stderr:write("mount: no such device\n")return 1 end
local ok,e=fs.mount(b or"/mnt/"..a,found)
if not ok then io.stderr:write("mount: "..tostring(e).."\n")return 1 end
]=]},
{"/bin/mv.lua",[[
local fs=require("fs")
local p={...}
if#p<2 then io.stderr:write("usage: mv src... dest\n")return 1 end
local dest=table.remove(p)
local isdir=fs.isDir(dest)
if#p>1 and not isdir then io.stderr:write("mv: target is not a directory\n")return 1 end
local rc=0
for _,s in ipairs(p)do
  local ok,e=fs.rename(s,isdir and fs.concat(dest,fs.name(s))or dest)
  if not ok then io.stderr:write("mv: "..s..": "..tostring(e or"failed").."\n");rc=1 end
end
return rc
]]},
{"/bin/passwd.lua",[[
-- passwd [user]  (creates the user if missing; empty password = no password)
local users,term=require("users"),require("term")
local name=(...)or os.getenv("USER")or"root"
local a=term.read("New password for "..name..": ",{mask="*",history=false})
if a==nil then return 1 end
local b=term.read("Repeat: ",{mask="*",history=false})
if a~=b then io.stderr:write("passwords differ\n")return 1 end
users.set(name,a)
print("password updated"..(a==""and" (empty = no password)"or""))
]]},
{"/bin/ps.lua",[[
local sched=require("sched")
print("PID  PPID  UP(s)  NAME")
for _,p in ipairs(sched.list())do
  print(string.format("%-4d %-5s %-6d %s",p.pid,tostring(p.parent or"-"),math.floor(computer.uptime()-p.start),p.name))
end
]]},
{"/bin/pwd.lua",[[
print(require("fs").cwd())
]]},
{"/bin/reboot.lua",[[
computer.shutdown(true)
]]},
{"/bin/resolution.lua",[[
local term=require("term")
local w,h=tonumber((...)),tonumber((select(2,...)))
if not w or not h then
  local cw,ch=term.size()
  local mw,mh=term.gpu().maxResolution()
  print("current "..cw.."x"..ch..", max "..mw.."x"..mh.."   usage: resolution <w> <h>")
  return
end
term.setResolution(w,h)
]]},
{"/bin/rm.lua",[[
local fs,args=require("fs"),require("args")
local o,p=args.parse({...})
local rc=0
for _,f in ipairs(p)do
  if not fs.exists(f)then io.stderr:write("rm: "..f..": no such file\n");rc=1
  elseif fs.canonical(f)=="/"then io.stderr:write("rm: refusing to remove /\n");rc=1
  elseif fs.isDir(f)and not(o.r or o.R)then io.stderr:write("rm: "..f..": is a directory (use -r)\n");rc=1
  else fs.remove(f)end
end
return rc
]]},
{"/bin/shutdown.lua",[[
computer.shutdown()
]]},
{"/bin/sleep.lua",[[
os.sleep(tonumber((...))or 1)
]]},
{"/bin/sysinfo.lua",[=[
local term,fs,text=require("term"),require("fs"),require("text")
local function c(n,s)return"\27["..n.."m"..s.."\27[0m"end
local logo={[[ _____              ___  ____  ]],[[|__  /___ _ __    / _ \/ ___| ]],
[[  / // _ \ '_ \  | | | \___ \ ]],[[ / /|  __/ | | | | |_| |___) |]],[[/____\___|_| |_|  \___/|____/ ]]}
for _,l in ipairs(logo)do print(c(36,l))end
local w,h=term.size()
local n=0
for _ in component.list()do n=n+1 end
local t,f=computer.totalMemory(),computer.freeMemory()
local s=math.floor(computer.uptime())
local function row(k,v)print(c(32,text.rpad(k,9))..v)end
print()
row("User",(os.getenv("USER")or"?").."@"..(os.getenv("HOSTNAME")or"zen"))
row("OS",_OSNAME.." ".._OSVERSION)
row("Lua",_VERSION)
row("Uptime",string.format("%dh %02dm %02ds",s//3600,s%3600//60,s%60))
row("Memory",text.size(t-f).." / "..text.size(t))
row("Energy",math.floor(computer.energy()).." / "..math.floor(computer.maxEnergy()))
row("Screen",w.."x"..h)
row("Devices",n.." components")
]=]},
{"/bin/tail.lua",[[
local fs,args,text=require("fs"),require("args"),require("text")
local o,p=args.parse({...},{n=true})
local n=tonumber(o.n)or 10
local d=p[1]and fs.readfile(p[1])or io.read("a")or""
local l=text.lines(d)
for i=math.max(1,#l-n+1),#l do print(l[i])end
]]},
{"/bin/touch.lua",[[
local fs=require("fs")
for _,f in ipairs{...}do if not fs.exists(f)then fs.writefile(f,"")end end
]]},
{"/bin/tree.lua",[[
local fs=require("fs")
local function walk(path,prefix)
  local l=fs.list(path)
  table.sort(l)
  for i,n in ipairs(l)do
    local last=i==#l
    print(prefix..(last and"└── "or"├── ")..n)
    if n:sub(-1)=="/"then walk(fs.concat(path,n),prefix..(last and"    "or"│   "))end
  end
end
local root=...or"."
print(root)
walk(root,"")
]]},
{"/bin/umount.lua",[[
local fs=require("fs")
if not fs.umount((...)or"")then io.stderr:write("umount: not a mount point\n")return 1 end
]]},
{"/bin/uptime.lua",[[
local s=math.floor(computer.uptime())
print(string.format("up %dh %02dm %02ds",s//3600,s%3600//60,s%60))
]]},
{"/bin/wc.lua",[[
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
]]},
{"/bin/wget.lua",[[
-- wget <url> [file|-]
local fs=require("fs")
local url,path=...
if not url then io.stderr:write("usage: wget <url> [file|-]\n")return 1 end
path=path or url:match("([^/]+)$")or"index.html"
local inet=component.list("internet")()
if not inet then io.stderr:write("wget: no internet card\n")return 1 end
local ok,h=pcall(component.invoke,inet,"request",url)
if not ok or not h then io.stderr:write("wget: "..tostring(h).."\n")return 1 end
local out
if path~="-"then
  local e
  out,e=fs.open(path,"w")
  if not out then io.stderr:write("wget: "..tostring(e).."\n")return 1 end
end
local total=0
while true do
  local s,e=h.read()
  if not s then
    if e then io.stderr:write("wget: "..tostring(e).."\n")end
    break
  end
  if s==""then os.sleep(0.05)
  else
    total=total+#s
    if out then out:write(s)else io.write(s)end
  end
end
h.close()
if out then out:close();print(path..": "..total.." bytes")end
]]},
{"/bin/whoami.lua",[[
print(os.getenv("USER")or"?")
]]},
{"/boot/bios.lua",[[
-- ZenBIOS 1.0 - EEPROM firmware (must stay < 4096 bytes)
local c,p,u=component,computer,unicode
local I=c.invoke
local function F(t)return c.list(t)()end
local G,S,E=F("gpu"),F("screen"),F("eeprom")
local y=1
-- getBootAddress/setBootAddress are not part of the base API: keep them in EEPROM data
p.getBootAddress=function()return E and I(E,"getData")or""end
p.setBootAddress=function(a)return E and I(E,"setData",a)end
if G and S then I(G,"bind",S)I(G,"setResolution",50,16)end
local function cls()
 if G then I(G,"setBackground",0)I(G,"fill",1,1,50,16," ")end
 y=1
end
local function pr(s,f)
 if G then
  if y>16 then I(G,"copy",1,2,50,15,1,1)I(G,"fill",1,16,50,1," ")y=16 end
  I(G,"setForeground",f or 0xFFFFFF)I(G,"set",1,y,s)
 end
 y=y+1
end
local function pw(s,f)for i=1,math.max(#s,1),50 do pr(s:sub(i,i+49),f)end end
local function key()
 while 1 do
  local e,_,ch,co=p.pullSignal()
  if e=="key_down"then return ch,co end
 end
end
local function rl(m)
 local b=""
 while 1 do
  if G then
   if y>16 then pr("")y=16 end
   I(G,"setForeground",0xFFFFFF)I(G,"fill",1,y,50,1," ")I(G,"set",1,y,u.sub(m..b.."_",-50))
  end
  local ch,co=key()
  if co==28 then y=y+1 return b
  elseif co==14 then b=u.sub(b,1,-2)
  elseif ch>31 then b=b..u.char(ch)end
 end
end
local function rd(a,f)
 local h=I(a,"open",f)
 if not h then return end
 local d,s=""
 repeat s=I(a,"read",h,math.huge)d=d..(s or"")until not s
 I(a,"close",h)
 return d
end
local function run(d,n)
 local f,e=load(d,"="..n)
 if f then f,e=pcall(f)if f then return end end
 cls()pr("Error in "..n,0xFF0000)pw(tostring(e),0xFF8080)pr("Press any key",0x888888)
 p.beep(200,.3)key()
end
local function boot(a)
 local d=rd(a,"/init.lua")
 if d then
  if p.getBootAddress()~=a then p.setBootAddress(a)end
  run(d,"init")
 end
end
local function lua()
 cls()pr("Lua prompt - 'exit' to leave",0x00FFFF)
 while 1 do
  local l=rl("> ")
  if l=="exit"then return end
  local f,e=load("return "..l,"=lua")
  if not f then f,e=load(l,"=lua")end
  if f then
   local r=table.pack(pcall(f))
   if r[1]then for i=2,r.n do pw(tostring(r[i]))end else pw(tostring(r[2]),0xFF8080)end
  else pw(tostring(e),0xFF8080)end
 end
end
local function net()
 cls()
 local n=F("internet")
 if not n then pr("No internet card",0xFF0000)key()return end
 local d=(E and I(E,"getData")or""):match("^https?://%S+")or""
 local url=rl("URL"..(d~=""and" ["..d:sub(1,30).."]"or"")..": ")
 if url==""then url=d end
 if url==""then return end
 local h,e=I(n,"request",url)
 if not h then pw(tostring(e),0xFF0000)key()return end
 local t=""
 while 1 do
  local s,r=h.read()
  if not s then break end
  t=t..s
  if s==""then p.pullSignal(.1)end
 end
 h.close()
 run(t,"net")
end
local function menu(m)
 local s=1
 while 1 do
  cls()
  pr("ZenBIOS 1.0   Boot menu",0x00FF00)pr("")
  for i,e in ipairs(m)do pr((i==s and"> "or"  ")..e[1],i==s and 0xFFFF00 or 0xFFFFFF)end
  pr("")pr("Up/Down + Enter",0x888888)
  local _,co=key()
  if co==200 then s=(s-2)%#m+1
  elseif co==208 then s=s%#m+1
  elseif co==28 then return m[s]end
 end
end
cls()
pr("ZenBIOS 1.0",0x00FF00)
pr(math.floor(p.totalMemory()/1024).."K RAM",0x888888)
pr("Press any key for the boot menu...",0x888888)
local t,k=p.uptime()+1.5
repeat k=p.pullSignal(.1)=="key_down"until k or p.uptime()>t
local d=p.getBootAddress()
if not k and#d>0 then pcall(boot,d)end
local auto=not k
while 1 do
 local m={}
 for a in c.list("filesystem")do
  local ok,ex=pcall(I,a,"exists","/init.lua")
  if ok and ex and a~=p.tmpAddress()then
   m[#m+1]={(I(a,"getLabel")or"disk").." ("..a:sub(1,6)..")",function()boot(a)end}
  end
 end
 if auto and m[1]then auto=nil m[1][2]()end
 m[#m+1]={"Network boot",net}
 m[#m+1]={"Lua prompt",lua}
 m[#m+1]={"Reboot",function()p.shutdown(true)end}
 m[#m+1]={"Shutdown",function()p.shutdown()end}
 menu(m)[2]()
end
]]},
{"/etc/hostname",[[
zen
]]},
{"/etc/motd",[[
[33mWelcome to ZenOS.[0m Type [32mhelp[0m for commands, [32msysinfo[0m for system info.
]]},
{"/etc/profile.lua",[[
-- Runs after every login. Put your aliases and variables here.
local sh=require("sh")
sh.aliases.ll="ls -l"
sh.aliases.la="ls -a"
sh.aliases[".."]="cd .."
sh.aliases.cls="clear"
sh.aliases.halt="shutdown"
-- os.setenv("PS1","\\u@\\h:\\w\\$ ")   -- custom prompt: \u user, \h host, \w dir, \$ # or $
]]},
{"/etc/rc.d/10-hostname.lua",[[
-- Applies /etc/hostname to the init environment
local fs=require("fs")
local h=(fs.readfile("/etc/hostname")or""):match("%S+")
if h then os.setenv("HOSTNAME",h)end
]]},
{"/init.lua",[[
-- ZenOS 1.0 kernel loader. Started by ZenBIOS (or any OpenOS-style BIOS).
_OSNAME,_OSVERSION="ZenOS","1.0"
local boot=computer.getBootAddress()
local inv=component.invoke

local function rawread(path)
  local h=inv(boot,"open",path,"r")
  if not h then return nil end
  local d,s=""
  repeat s=inv(boot,"read",h,math.huge);d=d..(s or"")until not s
  inv(boot,"close",h)
  return d
end

package={loaded={},preload={},path="/lib/?.lua;/usr/lib/?.lua",reader=rawread}
for _,n in ipairs{"string","table","math","coroutine","os","utf8","debug","component","computer","unicode"}do
  package.loaded[n]=_G[n]
end
package.loaded._G=_G

function package.find(name)
  local n=name:gsub("%.","/")
  for pat in package.path:gmatch("[^;]+")do
    local f=pat:gsub("%?",function()return n end)
    local d=package.reader(f)
    if d then return d,f end
  end
end

function require(name)
  local l=package.loaded
  if l[name]~=nil then return l[name]end
  local fn,f
  if package.preload[name]then
    fn=package.preload[name]
  else
    local d
    d,f=package.find(name)
    if not d then error("module '"..name.."' not found",2)end
    local e
    fn,e=load(d,"="..f,"t",_ENV)
    if not fn then error(e,0)end
  end
  local r=fn(name,f)
  if r==nil then r=l[name]end
  if r==nil then r=true end
  l[name]=r
  return r
end

local function main()
  local fs=require("fs")
  assert(fs.mount("/",boot))
  package.reader=fs.readfile

  function loadfile(path,mode,env)
    local d,e=fs.readfile(path)
    if not d then return nil,e end
    if d:sub(1,2)=="#!"then d="--"..d end
    return load(d,"="..path,mode or"t",env or _ENV)
  end
  function dofile(path,...)
    local f,e=loadfile(path)
    if not f then error(e,0)end
    return f(...)
  end

  local tmp=computer.tmpAddress()
  if tmp then fs.mount("/tmp",tmp)end
  local term=require("term")
  assert(term.init(),"no GPU/screen found")
  require("stdio")
  local sched=require("sched")
  fs.automount()
  math.randomseed(os.time()+math.floor(computer.uptime()*1000))
  sched.spawn(function()dofile("/sbin/init.lua")end,"init",{
    env={PATH="/bin:/usr/bin:/home/bin",HOME="/home",USER="root",PWD="/",HOSTNAME="zen"},
    stdin=term.stream,stdout=term.stream,stderr=term.stream})
  sched.run()
end

local ok,err=xpcall(main,debug.traceback)
if not ok then
  local g=component.list("gpu")()
  if g then
    local gpu=component.proxy(g)
    gpu.setBackground(0x0000AA);gpu.setForeground(0xFFFFFF)
    local w,h=gpu.getResolution()
    gpu.fill(1,1,w,h," ")
    gpu.set(1,1,"ZenOS kernel panic")
    local y=3
    for l in tostring(err):gmatch("[^\n]+")do
      gpu.set(1,y,(l:gsub("\t","  ")):sub(1,w))
      y=y+1
      if y>h-2 then break end
    end
    gpu.set(1,h,"Press any key to reboot")
  end
  repeat local e=computer.pullSignal()until e=="key_down"
  computer.shutdown(true)
end
computer.shutdown()
]]},
{"/lib/args.lua",[[
-- args.parse(argv, {x=true}) -> flags, positional   (x=true: option -x takes a value)
local M={}
function M.parse(argv,withval)
  local o,p={},{}
  local i=1
  while i<=#argv do
    local a=argv[i]
    if a=="--"then
      for j=i+1,#argv do p[#p+1]=argv[j]end
      break
    elseif a:sub(1,2)=="--"then
      local k,v=a:match("^%-%-([^=]+)=?(.*)$")
      o[k]=v~=""and v or true
    elseif a:sub(1,1)=="-"and#a>1 and not tonumber(a)then
      for c in a:sub(2):gmatch(".")do
        if withval and withval[c]then i=i+1;o[c]=argv[i]else o[c]=true end
      end
    else p[#p+1]=a end
    i=i+1
  end
  return o,p
end
return M
]]},
{"/lib/event.lua",[[
local s=require("sched")
return{pull=s.pull,listen=s.listen,ignore=s.ignore,timer=s.timer,cancel=s.cancel,
  push=computer.pushSignal,sleep=s.sleep}
]]},
{"/lib/fs.lua",[[
-- ZenOS virtual filesystem: mount points over OpenComputers filesystem components
local stream=require("stream")
local F={}
local mounts={}

local function cwd()
  local s=package.loaded.sched
  local p=s and s.current()
  return p and p.env.PWD or"/"
end
F.cwd=cwd

function F.canonical(path,base)
  if path:sub(1,1)~="/"then path=(base or cwd()).."/"..path end
  local parts={}
  for seg in path:gmatch("[^/]+")do
    if seg==".."then parts[#parts]=nil
    elseif seg~="."then parts[#parts+1]=seg end
  end
  return"/"..table.concat(parts,"/")
end
function F.concat(a,b)return(a:gsub("/+$",""))..  "/"..(b:gsub("^/+",""))end
function F.name(path)return path:match("([^/]*)/*$")or""end
function F.dir(path)
  local d=path:gsub("/+$",""):match("^(.*)/[^/]*$")
  if d==nil then return nil end
  return d==""and"/"or d
end

function F.mount(path,dev)
  path=F.canonical(path,"/")
  local px=type(dev)=="string"and component.proxy(dev)or dev
  if not px then return nil,"no such device"end
  mounts[path]=px
  return true
end
function F.umount(path)
  path=F.canonical(path)
  if path=="/"or not mounts[path]then return false end
  mounts[path]=nil
  return true
end
function F.mounts()
  local t={}
  for mp,px in pairs(mounts)do t[#t+1]={path=mp,proxy=px}end
  table.sort(t,function(a,b)return a.path<b.path end)
  return t
end

local function resolve(path)
  path=F.canonical(path)
  local best,blen
  for mp in pairs(mounts)do
    if mp=="/"or path==mp or path:sub(1,#mp+1)==mp.."/"then
      if not blen or#mp>blen then best,blen=mp,#mp end
    end
  end
  if not best then return nil,"no filesystem mounted"end
  local rel=path:sub(best=="/"and 1 or#best+1)
  if rel==""then rel="/"end
  return mounts[best],rel,path,best
end
F.proxyOf=resolve

local function virtualdir(abs)
  local prefix=abs=="/"and"/"or abs.."/"
  for mp in pairs(mounts)do
    if mp~=abs and mp:sub(1,#prefix)==prefix then return true end
  end
  return false
end

function F.exists(p)
  local px,rel,abs=resolve(p)
  if not px then return false end
  if rel=="/"then return true end
  return px.exists(rel)or virtualdir(abs)
end
function F.isDir(p)
  local px,rel,abs=resolve(p)
  if not px then return false end
  if rel=="/"then return true end
  return px.isDirectory(rel)or(not px.exists(rel)and virtualdir(abs))
end
function F.list(p)
  local px,rel,abs=resolve(p)
  if not px then return{}end
  local out,seen={},{}
  for _,n in ipairs(px.list(rel)or{})do out[#out+1]=n;seen[(n:gsub("/$",""))]=true end
  local prefix=abs=="/"and"/"or abs.."/"
  for mp in pairs(mounts)do
    if mp~=abs and mp:sub(1,#prefix)==prefix then
      local seg=mp:sub(#prefix+1):match("^[^/]+")
      if seg and not seen[seg]then seen[seg]=true;out[#out+1]=seg.."/"end
    end
  end
  return out
end
function F.size(p)local px,rel=resolve(p)return px and px.size(rel)or 0 end
function F.mtime(p)local px,rel=resolve(p)return px and px.lastModified(rel)or 0 end
function F.mkdir(p)local px,rel=resolve(p)return px and px.makeDirectory(rel)end
function F.remove(p)
  local px,rel,abs=resolve(p)
  if not px or abs=="/"then return false end
  if px.isDirectory(rel)then
    for _,n in ipairs(px.list(rel)or{})do F.remove(abs.."/"..(n:gsub("/$","")))end
  end
  return px.remove(rel)
end
function F.copy(a,b)
  if F.isDir(a)then
    F.mkdir(b)
    for _,n in ipairs(F.list(a))do
      local ok,e=F.copy(F.concat(a,n),F.concat(b,n))
      if not ok then return nil,e end
    end
    return true
  end
  local pa,ra=resolve(a)
  local pb,rb=resolve(b)
  if not pa or not pa.exists(ra)then return nil,a..": no such file"end
  local ha=pa.open(ra,"r")
  if not ha then return nil,"cannot open "..a end
  local hb,e=pb.open(rb,"w")
  if not hb then pa.close(ha);return nil,tostring(e or"cannot write "..b)end
  while true do
    local d=pa.read(ha,4096)
    if not d then break end
    local ok,we=pb.write(hb,d)
    if not ok then pa.close(ha);pb.close(hb);return nil,tostring(we or"write error")end
  end
  pa.close(ha);pb.close(hb)
  return true
end
function F.rename(a,b)
  local pa,ra=resolve(a)
  local pb,rb=resolve(b)
  if not pa or not pb then return nil,"no filesystem"end
  if pa==pb then return pa.rename(ra,rb)end
  local ok,e=F.copy(a,b)
  if not ok then return nil,e end
  return F.remove(a)
end

local File={}
File.__index=File
stream.mix(File)
function File:fill()
  if self.eof or not self.h then return false end
  local d=self.px.read(self.h,4096)
  if d and#d>0 then self.buf=self.buf..d;return true end
  self.eof=true
  return false
end
function File:write(...)
  for i=1,select("#",...)do
    local ok,e=self.px.write(self.h,tostring((select(i,...))))
    if not ok then return nil,e end
  end
  return self
end
function File:seek(wh,off)
  wh=wh or"cur";off=off or 0
  if wh=="cur"then off=off-#self.buf end
  self.buf="";self.eof=false
  return self.px.seek(self.h,wh,off)
end
function File:close()
  if self.h then self.px.close(self.h);self.h=nil end
  return true
end
function File:flush()return self end
function File:setvbuf()return true end

function F.open(path,mode)
  mode=(mode or"r"):sub(1,1)
  local px,rel=resolve(path)
  if not px then return nil,rel end
  if mode=="r"and not px.exists(rel)then return nil,path..": no such file"end
  local h,e=px.open(rel,mode)
  if not h then return nil,tostring(e or"cannot open "..path)end
  return setmetatable({px=px,h=h,buf=""},File)
end
function F.readfile(path)
  local f,e=F.open(path,"r")
  if not f then return nil,e end
  local d=f:read("a")
  f:close()
  return d or""
end
function F.writefile(path,data)
  local f,e=F.open(path,"w")
  if not f then return nil,e end
  local ok,we=f:write(data)
  f:close()
  if not ok then return nil,we end
  return true
end

function F.automount()
  local sched=require("sched")
  local function add(addr)
    local root=mounts["/"]
    if addr==computer.tmpAddress()or(root and root.address==addr)then return end
    F.mount("/mnt/"..addr:sub(1,3),component.proxy(addr))
  end
  for a in component.list("filesystem")do add(a)end
  sched.listen("component_added",function(_,a,t)if t=="filesystem"then add(a)end end)
  sched.listen("component_removed",function(_,a,t)
    if t=="filesystem"then
      for mp,px in pairs(mounts)do if px.address==a then mounts[mp]=nil end end
    end
  end)
end
return F
]]},
{"/lib/keys.lua",[[
-- Ctrl+<letter> detection (control character OR ctrl modifier state + scancode)
local sched=require("sched")
local K={}
local map={a={1,30},c={3,46},d={4,32},e={5,18},k={11,37},l={12,38},q={17,16},s={19,31},u={21,22}}
function K.ctrl(ch,code,n)
  local m=map[n]
  return ch==m[1]or(sched.ctrl and code==m[2])or false
end
return K
]]},
{"/lib/sched.lua",[[
-- ZenOS scheduler: cooperative processes (coroutines), signals, listeners, timers
local S={ctrl=false}
local procs,nextpid,current={},1,nil
local listeners,timers,nid={},{},0
local INT=setmetatable({},{__tostring=function()return"interrupted"end})
S.INT=INT

local function now()return computer.uptime()end
function S.current()return current end
function S.setraw(v)if current then current.raw=v end end

function S.list()
  local t={}
  for _,p in pairs(procs)do t[#t+1]=p end
  table.sort(t,function(a,b)return a.pid<b.pid end)
  return t
end

function S.spawn(fn,name,o)
  o=o or{}
  local par=current
  local p={pid=nextpid,name=name or"proc",parent=par and par.pid,ready=true,start=now(),env={}}
  nextpid=nextpid+1
  for k,v in pairs(o.env or(par and par.env)or{})do p.env[k]=v end
  p.stdin=o.stdin or(par and par.stdin)
  p.stdout=o.stdout or(par and par.stdout)
  p.stderr=o.stderr or(par and par.stderr)or p.stdout
  p.co=coroutine.create(fn)
  procs[p.pid]=p
  return p.pid
end

function S.kill(pid)
  local p=procs[pid]
  if not p then return false end
  if p==current then error("killed",0)end
  procs[pid]=nil
  return true
end

local function resume(p,...)
  current=p
  p.ready=false;p.filter=nil;p.deadline=nil
  local ok,tag,a,b=coroutine.resume(p.co,...)
  current=nil
  if not ok then
    procs[p.pid]=nil
    local out=p.stderr or p.stdout
    if out and tag~=INT and tag~="interrupted"and tag~="killed"then
      pcall(function()out:write("["..p.pid.."] "..p.name..": "..tostring(tag).."\n")end)
    end
  elseif coroutine.status(p.co)=="dead"then
    procs[p.pid]=nil
  elseif tag=="wait"then
    p.filter=a;p.deadline=b
  else
    p.ready=true
  end
end

-- pull([timeout,] [name, ...]) - waits for a signal (cooperatively)
function S.pull(...)
  local a=table.pack(...)
  local timeout,i
  i=1
  if type(a[1])=="number"then timeout=a[1];i=2 end
  local name=a[i]
  local extra={n=0}
  for j=i+1,a.n do extra[j-i]=a[j];extra.n=j-i end
  local p=current
  local deadline=timeout and now()+timeout or nil
  if not p then
    while true do
      local r=table.pack(computer.pullSignal(deadline and math.max(0,deadline-now())or math.huge))
      if r.n==0 then return nil end
      if name==nil or r[1]==name then return table.unpack(r,1,r.n)end
      if deadline and now()>=deadline then return nil end
    end
  end
  while true do
    local r=table.pack(coroutine.yield("wait",name,deadline))
    if r[1]==INT then error("interrupted",0)end
    if r.n==0 then return nil end
    local ok=true
    for j=1,extra.n do
      if extra[j]~=nil and r[j+1]~=extra[j]then ok=false end
    end
    if ok then return table.unpack(r,1,r.n)end
  end
end

function S.sleep(t)S.pull(t or 0,"\0never")end

function S.listen(name,fn)nid=nid+1;listeners[nid]={name=name,fn=fn};return nid end
function S.ignore(id)listeners[id]=nil end
function S.timer(interval,fn,times)
  nid=nid+1
  local left=times or 1
  if left==math.huge then left=nil end
  timers[nid]={at=now()+interval,interval=interval,fn=fn,left=left}
  return nid
end
function S.cancel(id)timers[id]=nil end

local function sortedkeys(t)
  local k={}
  for id in pairs(t)do k[#k+1]=id end
  table.sort(k)
  return k
end

function S.run()
  while next(procs)do
    for _,p in ipairs(S.list())do
      if procs[p.pid]==p and p.ready then resume(p)end
    end
    if not next(procs)then break end
    local n=now()
    local t=math.huge
    for _,p in pairs(procs)do
      if p.ready then t=0 elseif p.deadline and p.deadline-n<t then t=p.deadline-n end
    end
    for _,tm in pairs(timers)do if tm.at-n<t then t=tm.at-n end end
    if t<0 then t=0 end
    local sig=table.pack(computer.pullSignal(t))
    n=now()
    local intr=false
    if sig.n>0 then
      local nm=sig[1]
      if nm=="key_down"then
        if sig[4]==29 or sig[4]==157 then S.ctrl=true end
        intr=sig[3]==3 or(S.ctrl and sig[4]==46)or false
      elseif nm=="key_up"and(sig[4]==29 or sig[4]==157)then
        S.ctrl=false
      end
      for _,id in ipairs(sortedkeys(listeners))do
        local l=listeners[id]
        if l and(l.name==nil or l.name==nm)then
          local ok,r=pcall(l.fn,table.unpack(sig,1,sig.n))
          if ok and r==false then listeners[id]=nil end
        end
      end
    end
    for _,id in ipairs(sortedkeys(timers))do
      local tm=timers[id]
      if tm and n>=tm.at then
        if tm.left then
          tm.left=tm.left-1
          if tm.left<=0 then timers[id]=nil end
        end
        tm.at=n+tm.interval
        pcall(tm.fn)
      end
    end
    for _,p in ipairs(S.list())do
      if procs[p.pid]==p then
        if intr and p.fg and not p.raw and not p.ready then
          resume(p,INT)
        elseif p.ready then
          -- became ready during this round: runs at the top of the next loop
        elseif sig.n>0 and(p.filter==nil or p.filter==sig[1])then
          resume(p,table.unpack(sig,1,sig.n))
        elseif p.deadline and n>=p.deadline then
          resume(p)
        end
      end
    end
  end
end
return S
]]},
{"/lib/sh.lua",[[
-- ZenOS shell: quotes, $VARS, pipes, > >> <, && || ; &, globs, aliases, builtins, completion
local fs=require("fs")
local sched=require("sched")
local term=require("term")
local stream=require("stream")
local sh={aliases={},builtins={}}
local B=sh.builtins

local function var(line,i,e)
  local nx=line:sub(i+1,i+1)
  if nx=="{"then
    local j=line:find("}",i+2,true)
    if j then return tostring(e[line:sub(i+2,j-1)]or""),j+1 end
  elseif nx=="?"or nx:match("^%d$")then
    return tostring(e[nx]or""),i+2
  else
    local name=line:match("^[%a_][%w_]*",i+1)
    if name then return tostring(e[name]or""),i+1+#name end
  end
  return"$",i+1
end

local function tokenize(line,e)
  local toks,cur,glob,i,n={},nil,false,1,#line
  local function push()
    if cur~=nil then toks[#toks+1]={w=cur,glob=glob};cur=nil;glob=false end
  end
  while i<=n do
    local c=line:sub(i,i)
    if c==" "or c=="\t"then
      push();i=i+1
    elseif c=="#"and cur==nil then
      break
    elseif c=="'"then
      local j=line:find("'",i+1,true)
      if not j then return nil,"unterminated '"end
      cur=(cur or"")..line:sub(i+1,j-1);i=j+1
    elseif c=='"'then
      cur=cur or"";i=i+1
      while true do
        if i>n then return nil,'unterminated "'end
        local d=line:sub(i,i)
        if d=='"'then i=i+1;break
        elseif d=="\\"and line:sub(i+1,i+1):match('[\\"$]')then
          cur=cur..line:sub(i+1,i+1);i=i+2
        elseif d=="$"then
          local v,ni=var(line,i,e);cur=cur..v;i=ni
        else cur=cur..d;i=i+1 end
      end
    elseif c=="\\"then
      cur=(cur or"")..line:sub(i+1,i+1);i=i+2
    elseif c=="$"then
      local v,ni=var(line,i,e);cur=(cur or"")..v;i=ni
    elseif c=="~"and cur==nil and line:sub(i+1,i+1):match("^[/ ]?$")then
      cur=e.HOME or"/";i=i+1
    elseif c=="|"or c=="&"or c==";"or c==">"or c=="<"then
      push()
      local two=line:sub(i,i+1)
      if two=="||"or two=="&&"or two==">>"then toks[#toks+1]={op=two};i=i+2
      else toks[#toks+1]={op=c};i=i+1 end
    else
      if c=="*"or c=="?"then glob=true end
      cur=(cur or"")..c;i=i+1
    end
  end
  push()
  return toks
end

local function parse(toks)
  local items,pl,cmd={},{},{args={}}
  local function fin()
    if#cmd.args==0 and not cmd.inp and not cmd.out then return false end
    pl[#pl+1]=cmd;cmd={args={}}
    return true
  end
  local i=1
  while i<=#toks do
    local t=toks[i]
    if t.w then
      cmd.args[#cmd.args+1]=t
    elseif t.op=="|"then
      if not fin()then return nil,"syntax error near |"end
    elseif t.op==">"or t.op==">>"or t.op=="<"then
      local nx=toks[i+1]
      if not nx or not nx.w then return nil,"file expected after "..t.op end
      if t.op=="<"then cmd.inp=nx.w else cmd.out=nx.w;cmd.append=(t.op==">>")end
      i=i+1
    else
      local had=fin()
      if not had and#pl==0 then
        if t.op~=";"then return nil,"syntax error near "..t.op end
      else
        items[#items+1]={pl=pl,sep=(t.op=="&"and";")or t.op,bg=(t.op=="&")}
        pl={}
      end
    end
    i=i+1
  end
  fin()
  if#pl>0 then items[#items+1]={pl=pl,sep=";"}end
  return items
end

local function glob(pat)
  local dir,fp=pat:match("^(.*)/([^/]*)$")
  if not dir then dir,fp=".",pat elseif dir==""then dir="/"end
  local lp="^"..fp:gsub("[%^%$%(%)%%%.%[%]%+%-]","%%%0"):gsub("%*",".*"):gsub("%?",".").."$"
  local res={}
  local list=fs.list(dir)
  table.sort(list)
  for _,n in ipairs(list)do
    local nn=n:gsub("/$","")
    if(nn:sub(1,1)~="."or fp:sub(1,1)==".")and nn:match(lp)then
      res[#res+1]=(dir=="."and""or(dir=="/"and"/"or dir.."/"))..nn
    end
  end
  return res
end

local function find(name,e)
  local cands={}
  if name:find("/",1,true)then cands={name}
  else
    for dir in(e.PATH or"/bin"):gmatch("[^:;]+")do cands[#cands+1]=dir.."/"..name end
  end
  for _,c in ipairs(cands)do
    for _,ext in ipairs{".lua",".sh",""}do
      local f=c..ext
      if fs.exists(f)and not fs.isDir(f)then return fs.canonical(f)end
    end
  end
end

function sh.script(path,args)
  local d,e=fs.readfile(path)
  if not d then io.stderr:write(tostring(e).."\n");return 1 end
  local p=sched.current()
  for i=0,9 do p.env[tostring(i)]=nil end
  p.env["0"]=path
  for i,a in ipairs(args or{})do p.env[tostring(i)]=a end
  local st=0
  for l in d:gmatch("[^\n]+")do
    if l:match("%S")and not l:match("^%s*#")then st=sh.execute(l)end
  end
  return st
end

local function exec(name,args)
  local b=B[name]
  if b then return b(args)or 0 end
  local path=find(name,sched.current().env)
  if not path then io.stderr:write(name..": command not found\n");return 127 end
  if path:match("%.sh$")then return sh.script(path,args)end
  local f,e=loadfile(path)
  if not f then io.stderr:write(name..": "..tostring(e).."\n");return 1 end
  local r=f(table.unpack(args))
  return type(r)=="number"and r or 0
end

local function runcmd(cmd,stdin,stdout)
  local p=sched.current()
  local args={}
  for _,t in ipairs(cmd.args)do
    if t.glob then
      local m=glob(t.w)
      if#m>0 then for _,v in ipairs(m)do args[#args+1]=v end else args[#args+1]=t.w end
    else args[#args+1]=t.w end
  end
  local name=table.remove(args,1)
  if not name then return 0 end
  local k,v=name:match("^([%a_][%w_]*)=(.*)$")
  if k then p.env[k]=v;return 0 end
  local al=sh.aliases[name]
  if al then
    local at=tokenize(al,p.env)
    if at and#at>0 then
      local pre={}
      for _,t in ipairs(at)do if t.w then pre[#pre+1]=t.w end end
      if#pre>0 then
        name=table.remove(pre,1)
        for i=#pre,1,-1 do table.insert(args,1,pre[i])end
      end
    end
  end
  local oi,oo=p.stdin,p.stdout
  if stdin then p.stdin=stdin end
  if stdout then p.stdout=stdout end
  p.fg=not p.isbg
  local status=0
  local ok,err=pcall(function()status=exec(name,args)end)
  p.fg=false
  p.stdin,p.stdout=oi,oo
  if not ok then
    if type(err)=="table"and err.exit then status=err.code or 0
    elseif err=="interrupted"then io.stderr:write("^C\n");status=130
    else io.stderr:write(name,": ",tostring(err),"\n");status=1 end
  end
  return tonumber(status)or 0
end

local function runpl(pl)
  local input
  local status=0
  for i,cmd in ipairs(pl)do
    local stdin,stdout,outfile
    if i==1 and cmd.inp then
      local d,e=fs.readfile(cmd.inp)
      if not d then io.stderr:write("sh: "..cmd.inp..": "..tostring(e).."\n");return 1 end
      stdin=stream.buffer(d)
    elseif input then
      stdin=input
    end
    if cmd.out then
      local e
      outfile,e=fs.open(cmd.out,cmd.append and"a"or"w")
      if not outfile then io.stderr:write("sh: "..cmd.out..": "..tostring(e).."\n");return 1 end
      stdout=outfile
    elseif i<#pl then
      stdout=stream.buffer()
    end
    status=runcmd(cmd,stdin,stdout)
    if outfile then outfile:close()end
    input=(i<#pl)and(cmd.out and stream.buffer()or stdout)or nil
  end
  return status
end

function sh.execute(line)
  local p=sched.current()
  local toks,err=tokenize(line,p.env)
  if not toks then io.stderr:write("sh: "..err.."\n");return 2 end
  local items,perr=parse(toks)
  if not items then io.stderr:write("sh: "..perr.."\n");return 2 end
  local status=0
  local prev=";"
  for _,it in ipairs(items)do
    if prev==";"or(prev=="&&"and status==0)or(prev=="||"and status~=0)then
      if it.bg then
        local pl=it.pl
        local nm=(pl[1].args[1]or{w="job"}).w
        local pid=sched.spawn(function()sched.current().isbg=true;runpl(pl)end,nm,{stdin=stream.buffer("")})
        io.write("[",pid,"]\n")
        status=0
      else
        status=runpl(it.pl)
      end
      p.env["?"]=status
    end
    prev=it.sep
  end
  return status
end

-- builtins ------------------------------------------------------------------
function B.cd(a)
  local e=sched.current().env
  local d=a[1]or e.HOME or"/"
  if d=="-"then d=e.OLDPWD or"/"end
  local abs=fs.canonical(d)
  if not fs.isDir(abs)then io.stderr:write("cd: ",d,": no such directory\n");return 1 end
  e.OLDPWD=e.PWD;e.PWD=abs
  return 0
end
function B.exit()sh.leave=true;return 0 end
B["true"]=function()return 0 end
B["false"]=function()return 1 end
function B.set()
  local e=sched.current().env
  local ks={}
  for k in pairs(e)do ks[#ks+1]=k end
  table.sort(ks)
  for _,k in ipairs(ks)do print(k.."="..tostring(e[k]))end
  return 0
end
function B.export(a)
  if#a==0 then return B.set(a)end
  local e=sched.current().env
  for _,s in ipairs(a)do
    local k,v=s:match("^([^=]+)=(.*)$")
    if k then e[k]=v end
  end
  return 0
end
function B.unset(a)
  local e=sched.current().env
  for _,k in ipairs(a)do e[k]=nil end
  return 0
end
function B.alias(a)
  if#a==0 then
    for k,v in pairs(sh.aliases)do print("alias "..k.."='"..v.."'")end
    return 0
  end
  for _,s in ipairs(a)do
    local k,v=s:match("^([^=]+)=(.*)$")
    if k then sh.aliases[k]=v
    elseif sh.aliases[s]then print("alias "..s.."='"..sh.aliases[s].."'")end
  end
  return 0
end
function B.unalias(a)for _,k in ipairs(a)do sh.aliases[k]=nil end return 0 end
function B.history()
  for i,l in ipairs(term.history)do print(string.format("%4d  %s",i,l))end
  return 0
end
function B.source(a)
  if not a[1]then io.stderr:write("usage: source <file>\n");return 1 end
  return sh.script(fs.canonical(a[1]),{table.unpack(a,2)})
end
B["."]=B.source
function B.which(a)
  local e=sched.current().env
  for _,n in ipairs(a)do
    if B[n]then print(n..": shell builtin")
    elseif sh.aliases[n]then print(n..": alias for "..sh.aliases[n])
    else print(find(n,e)or(n..": not found"))end
  end
  return 0
end

-- interactive ---------------------------------------------------------------
function sh.prompt()
  local e=sched.current().env
  local ps=e.PS1 or"\27[32m\\u@\\h\27[0m:\27[34m\\w\27[0m\\$ "
  return(ps:gsub("\\([uhw$])",function(c)
    if c=="u"then return e.USER or"?"
    elseif c=="h"then return e.HOSTNAME or"zen"
    elseif c=="$"then return e.USER=="root"and"#"or"$"
    else
      local cwd=e.PWD or"/"
      local home=e.HOME
      if home and home~="/"and(cwd==home or cwd:sub(1,#home+1)==home.."/")then
        cwd="~"..cwd:sub(#home+1)
      end
      return cwd
    end
  end))
end

function sh.complete(line)
  local e=sched.current().env
  local word=line:match("([^%s]*)$")
  local first=not line:sub(1,#line-#word):match("%S")
  local cands={}
  if first and not word:find("/",1,true)then
    local seen={}
    local function add(n)
      if n:sub(1,#word)==word and not seen[n]then seen[n]=true;cands[#cands+1]=n end
    end
    for k in pairs(B)do add(k)end
    for k in pairs(sh.aliases)do add(k)end
    for dir in(e.PATH or"/bin"):gmatch("[^:;]+")do
      if fs.isDir(dir)then
        for _,n in ipairs(fs.list(dir))do
          local nm=n:match("^(.*)%.lua$")or n:match("^(.*)%.sh$")
          if nm then add(nm)end
        end
      end
    end
  else
    local dir,prefix=word:match("^(.*/)([^/]*)$")
    if not dir then dir,prefix="",word end
    local ld=dir==""and"."or dir
    if fs.isDir(ld)then
      for _,n in ipairs(fs.list(ld))do
        if n:sub(1,#prefix)==prefix and(prefix~=""or n:sub(1,1)~=".")then
          cands[#cands+1]=dir..n
        end
      end
    end
  end
  table.sort(cands)
  return cands,word
end

function sh.interactive()
  while true do
    local line=term.read(sh.prompt(),{complete=sh.complete})
    if line==nil then return end
    if line:match("%S")then
      local ok,e=pcall(sh.execute,line)
      if not ok then io.stderr:write("sh: "..tostring(e).."\n")end
      if sh.leave then sh.leave=false;return end
    end
  end
end
return sh
]]},
{"/lib/stdio.lua",[[
-- Installs io.*, print and extra os.* functions bound to the current process streams
local fs=require("fs")
local sched=require("sched")
local term=require("term")

local function cur(w)
  local p=sched.current()
  return(p and p[w])or term.stream
end
local function proxy(w)
  return setmetatable({},{__index=function(_,k)
    local s=cur(w)
    local v=s[k]
    if type(v)=="function"then return function(_,...)return v(s,...)end end
    return v
  end})
end

io={}
io.stdin,io.stdout,io.stderr=proxy("stdin"),proxy("stdout"),proxy("stderr")
function io.write(...)cur("stdout"):write(...);return io.stdout end
function io.read(...)return cur("stdin"):read(...)end
function io.lines(path,...)
  if not path then return cur("stdin"):lines(...)end
  local f,e=fs.open(path,"r")
  if not f then error(e,2)end
  local fmts={...}
  return function()
    local r=f:read(table.unpack(fmts))
    if r==nil then f:close()end
    return r
  end
end
io.open=fs.open
function io.close(f)if f then f:close()end end

function print(...)
  local t={}
  for i=1,select("#",...)do t[i]=tostring((select(i,...)))end
  cur("stdout"):write(table.concat(t,"\t").."\n")
end

function os.sleep(t)sched.sleep(t)end
function os.exit(c)
  if c==true then c=0 elseif c==false then c=1 end
  error({exit=true,code=c or 0},0)
end
function os.getenv(k)local p=sched.current();return p and p.env[k]end
function os.setenv(k,v)local p=sched.current();if p then p.env[k]=v end end
function os.remove(p)return fs.remove(p)end
function os.rename(a,b)return fs.rename(a,b)end
]]},
{"/lib/stream.lua",[[
-- Shared stream helpers: read formats ("l","L","a",number) over an object with .buf and :fill()
local M={}
local R={}
function R:read(...)
  local n=select("#",...)
  local fmts={...}
  if n==0 then fmts={"l"};n=1 end
  local out={}
  for i=1,n do
    local f=fmts[i]
    if type(f)=="string"then f=f:gsub("^%*","")end
    local v
    if f=="a"then
      while self:fill()do end
      v=self.buf;self.buf=""
    elseif f=="l"or f=="L"then
      while true do
        local e=self.buf:find("\n",1,true)
        if e then
          v=self.buf:sub(1,f=="l"and e-1 or e);self.buf=self.buf:sub(e+1)
          break
        end
        if not self:fill()then
          if#self.buf>0 then v=self.buf;self.buf=""end
          break
        end
      end
    elseif f=="n"then
      local l=self:read("l")
      v=tonumber(l)
    elseif type(f)=="number"then
      while#self.buf<f and self:fill()do end
      if#self.buf>0 then v=self.buf:sub(1,f);self.buf=self.buf:sub(f+1)end
    end
    out[i]=v
    if v==nil then break end
  end
  return table.unpack(out,1,n)
end
function R:lines(...)
  local f={...}
  return function()return self:read(table.unpack(f))end
end
function M.mix(o)o.read=R.read;o.lines=R.lines end

function M.buffer(init)
  local b={buf=init or""}
  function b:fill()return false end
  function b:write(...)
    for i=1,select("#",...)do self.buf=self.buf..tostring((select(i,...)))end
    return self
  end
  function b:close()end
  function b:flush()return self end
  function b:setvbuf()return true end
  M.mix(b)
  return b
end
return M
]]},
{"/lib/term.lua",[[
-- ZenOS terminal: GPU text output (ANSI colours), line editor with history and completion
local stream=require("stream")
local sched=require("sched")
local keys=require("keys")
local T={history={}}
local gpu,W,H
local x,y=1,1
local FG,BG=0xCCCCCC,0x000000
local fg,bg=FG,BG
local CP=utf8 and utf8.charpattern or"[\0-\127\194-\244][\128-\191]*"
local PAL={[0]=0x000000,0xCC0000,0x00CC00,0xCCCC00,0x3366FF,0xCC00CC,0x00CCCC,0xCCCCCC}
local BRI={[0]=0x555555,0xFF5555,0x55FF55,0xFFFF55,0x6699FF,0xFF55FF,0x55FFFF,0xFFFFFF}

function T.init()
  local ga,sa=component.list("gpu")(),component.list("screen")()
  if not ga or not sa then return false end
  gpu=component.proxy(ga)
  gpu.bind(sa)
  local mw,mh=gpu.maxResolution()
  gpu.setResolution(mw,mh)
  W,H=gpu.getResolution()
  fg,bg=FG,BG
  T.clear()
  return true
end
function T.gpu()return gpu end
function T.size()return W,H end
function T.setResolution(w,h)
  gpu.setResolution(w,h)
  W,H=gpu.getResolution()
  T.clear()
end
function T.clear()
  gpu.setForeground(fg);gpu.setBackground(bg)
  gpu.fill(1,1,W,H," ")
  x,y=1,1
end
function T.getCursor()return x,y end
function T.setCursor(nx,ny)x,y=nx,ny end
function T.isatty()
  local p=sched.current()
  return not p or p.stdout==T.stream
end

local function sgr(params)
  if params==""then params="0"end
  for code in params:gmatch("%d+")do
    local n=tonumber(code)
    if n==0 then fg,bg=FG,BG
    elseif n>=30 and n<=37 then fg=PAL[n-30]
    elseif n>=90 and n<=97 then fg=BRI[n-90]
    elseif n>=40 and n<=47 then bg=PAL[n-40]
    elseif n>=100 and n<=107 then bg=BRI[n-100]
    elseif n==39 then fg=FG
    elseif n==49 then bg=BG
    elseif n==7 then fg,bg=bg,fg end
  end
  gpu.setForeground(fg);gpu.setBackground(bg)
end

local function newline()
  x=1;y=y+1
  if y>H then
    gpu.copy(1,2,W,H-1,1,1)
    gpu.fill(1,H,W,1," ")
    y=H
  end
end

function T.write(s)
  if not gpu then return end
  local run,rl,esc="",0,nil
  local function flush()
    if rl>0 then gpu.set(x,y,run);x=x+rl;run,rl="",0 end
  end
  for ch in tostring(s):gmatch(CP)do
    if esc then
      if esc=="\27"then
        if ch=="["then esc=""else esc=nil end
      elseif ch:match("[%d;]")then
        esc=esc..ch
      else
        local p=esc;esc=nil
        if ch=="m"then sgr(p)
        elseif ch=="J"then T.clear()
        elseif ch=="K"then gpu.fill(x,y,W-x+1,1," ")
        elseif ch=="H"then
          local r,c=p:match("(%d*);?(%d*)")
          y=math.min(H,tonumber(r)or 1);x=math.min(W,tonumber(c)or 1)
        end
      end
    elseif ch=="\27"then flush();esc="\27"
    elseif ch=="\n"then flush();newline()
    elseif ch=="\r"then flush();x=1
    elseif ch=="\b"then flush();x=math.max(1,x-1)
    elseif ch=="\t"then
      local n=8-((x+rl-1)%8)
      for _=1,n do
        if x+rl>W then flush();newline()end
        run=run.." ";rl=rl+1
      end
    else
      if x+rl>W then flush();newline()end
      run=run..ch;rl=rl+1
    end
  end
  flush()
end

local function common(list)
  local p=list[1]
  for i=2,#list do
    local b=list[i]
    local n=0
    local la,lb=unicode.len(p),unicode.len(b)
    while n<la and n<lb and unicode.sub(p,n+1,n+1)==unicode.sub(b,n+1,n+1)do n=n+1 end
    p=unicode.sub(p,1,n)
  end
  return p
end

-- term.read(prompt, {mask="*", complete=fn(line)->list,word, history=false})
-- returns the line, or nil on Ctrl+D
function T.read(prompt,opts)
  opts=opts or{}
  if prompt then T.write(prompt)end
  local proc=sched.current()
  if proc then proc.raw=true end
  local sx=x
  local buf,pos,off="",0,0
  local hist=T.history
  local hi=#hist+1
  local saved=""
  local function len()return unicode.len(buf)end
  local function draw(cursor)
    local avail=W-sx
    if pos<off then off=pos elseif pos>=off+avail then off=pos-avail+1 end
    local vis=unicode.sub(buf,off+1,off+avail)
    if opts.mask then vis=string.rep(opts.mask,unicode.len(vis))end
    gpu.setForeground(fg);gpu.setBackground(bg)
    gpu.fill(sx,y,W-sx+1,1," ")
    if vis~=""then gpu.set(sx,y,vis)end
    if cursor then
      local ch=unicode.sub(vis,pos-off+1,pos-off+1)
      if ch==""then ch=" "end
      gpu.setForeground(bg);gpu.setBackground(fg)
      gpu.set(sx+pos-off,y,ch)
      gpu.setForeground(fg);gpu.setBackground(bg)
    end
  end
  local function insert(s)
    buf=unicode.sub(buf,1,pos)..s..unicode.sub(buf,pos+1)
    pos=pos+unicode.len(s)
  end
  local result,done
  while not done do
    draw(true)
    local e,_,ch,code=sched.pull()
    if e=="key_down"then
      if code==28 or code==156 then result=buf;done=true
      elseif keys.ctrl(ch,code,"c")then result="";done=true;T.write("^C")
      elseif keys.ctrl(ch,code,"d")then
        if buf==""then result=nil;done=true
        elseif pos<len()then buf=unicode.sub(buf,1,pos)..unicode.sub(buf,pos+2)end
      elseif keys.ctrl(ch,code,"a")or code==199 then pos=0
      elseif keys.ctrl(ch,code,"e")or code==207 then pos=len()
      elseif keys.ctrl(ch,code,"u")then buf=unicode.sub(buf,pos+1);pos=0
      elseif keys.ctrl(ch,code,"k")then buf=unicode.sub(buf,1,pos)
      elseif keys.ctrl(ch,code,"l")then
        T.clear();T.write(prompt or"");sx=x;off=0
      elseif code==14 then
        if pos>0 then buf=unicode.sub(buf,1,pos-1)..unicode.sub(buf,pos+1);pos=pos-1 end
      elseif code==211 then
        if pos<len()then buf=unicode.sub(buf,1,pos)..unicode.sub(buf,pos+2)end
      elseif code==203 then pos=math.max(0,pos-1)
      elseif code==205 then pos=math.min(len(),pos+1)
      elseif code==200 then
        if hi>1 then
          if hi==#hist+1 then saved=buf end
          hi=hi-1;buf=hist[hi];pos=len()
        end
      elseif code==208 then
        if hi<=#hist then
          hi=hi+1
          buf=(hi==#hist+1)and saved or hist[hi]
          pos=len()
        end
      elseif code==15 and opts.complete then
        local cands,word=opts.complete(unicode.sub(buf,1,pos))
        if#cands==1 then
          local add=unicode.sub(cands[1],unicode.len(word)+1)
          if cands[1]:sub(-1)~="/"then add=add.." "end
          insert(add)
        elseif#cands>1 then
          local cp=common(cands)
          if unicode.len(cp)>unicode.len(word)then
            insert(unicode.sub(cp,unicode.len(word)+1))
          else
            draw(false);T.write("\n")
            local cw=0
            for _,c in ipairs(cands)do cw=math.max(cw,unicode.len(c))end
            cw=cw+2
            for i,c in ipairs(cands)do
              if x+cw>W+1 then T.write("\n")end
              T.write(c..string.rep(" ",cw-unicode.len(c)))
            end
            if x>1 then T.write("\n")end
            if prompt then T.write(prompt)end
            sx=x;off=0
          end
        end
      elseif ch>=32 and ch~=127 and not sched.ctrl then
        insert(unicode.char(ch))
      end
    elseif e=="clipboard"and type(ch)=="string"then
      local line=ch:match("^[^\r\n]*")
      if line~=""then insert(line)end
    end
  end
  draw(false)
  if result and result~=""and not opts.mask and unicode.len(result)>=W-sx then
    gpu.fill(sx,y,W-sx+1,1," ")
    x=sx
    T.write(result)
  end
  T.write("\n")
  if proc then proc.raw=false end
  if result and opts.history~=false and result:match("%S")and result~=hist[#hist]then
    hist[#hist+1]=result
    if#hist>100 then table.remove(hist,1)end
  end
  return result
end

T.stream={buf=""}
function T.stream:write(...)
  local t={}
  for i=1,select("#",...)do t[i]=tostring((select(i,...)))end
  T.write(table.concat(t))
  return self
end
function T.stream:fill()
  local l=T.read(nil,{history=false})
  if l==nil then return false end
  self.buf=self.buf..l.."\n"
  return true
end
function T.stream:close()end
function T.stream:flush()return self end
function T.stream:setvbuf()return true end
stream.mix(T.stream)
return T
]]},
{"/lib/text.lua",[[
local T={}
function T.trim(s)return(s:gsub("^%s+",""):gsub("%s+$",""))end
function T.split(s,sep)
  local t,i={},1
  while true do
    local j=s:find(sep,i,true)
    if not j then t[#t+1]=s:sub(i);return t end
    t[#t+1]=s:sub(i,j-1);i=j+#sep
  end
end
function T.size(n)
  n=n or 0
  local u,i={"B","K","M","G"},1
  while n>=1024 and i<#u do n=n/1024;i=i+1 end
  if i==1 then return string.format("%d%s",math.floor(n),u[i])end
  return string.format("%.1f%s",n,u[i])
end
function T.lines(d)
  local t={}
  if d==""then return t end
  for l in(d:gsub("\n$","").."\n"):gmatch("(.-)\n")do t[#t+1]=l end
  return t
end
function T.lpad(s,n)return string.rep(" ",n-unicode.len(s))..s end
function T.rpad(s,n)return s..string.rep(" ",n-unicode.len(s))end
return T
]]},
{"/lib/users.lua",[[
-- Simple user database (/etc/passwd: name:hash:salt:home). The hash is a salted
-- iterated FNV - it keeps casual players out, it is NOT cryptographic security.
local fs=require("fs")
local U={}
local FILE="/etc/passwd"

function U.hash(pw,salt)
  local s=salt..pw
  local function h(seed)
    local x=seed
    for r=1,100 do
      for i=1,#s do x=((x~s:byte(i))*16777619)&0xFFFFFFFF end
      x=((x~r)*16777619)&0xFFFFFFFF
    end
    return x
  end
  return string.format("%08x%08x",h(0x811C9DC5),h(0x01000193))
end
function U.all()
  local t={}
  local d=fs.readfile(FILE)or""
  for l in d:gmatch("[^\n]+")do
    local n,h,s,home=l:match("^([^:]*):([^:]*):([^:]*):(.*)$")
    if n then t[#t+1]={name=n,hash=h,salt=s,home=home}end
  end
  return t
end
function U.save(t)
  local o={}
  for _,u in ipairs(t)do o[#o+1]=table.concat({u.name,u.hash,u.salt,u.home},":")end
  return fs.writefile(FILE,table.concat(o,"\n").."\n")
end
function U.find(name)
  for _,u in ipairs(U.all())do if u.name==name then return u end end
end
function U.set(name,pw)
  local all=U.all()
  local u
  for _,x in ipairs(all)do if x.name==name then u=x end end
  if not u then
    u={name=name,home=name=="root"and"/home"or"/home/"..name}
    all[#all+1]=u
  end
  u.salt=string.format("%08x",math.random(0,0x7FFFFFFF))
  u.hash=pw==""and""or U.hash(pw,u.salt)
  return U.save(all)
end
function U.check(name,pw)
  local u=U.find(name)
  if not u then return false end
  if u.hash==""then return true end
  return U.hash(pw,u.salt)==u.hash
end
function U.login()
  local term=require("term")
  if#U.all()==0 then return"root","/home"end
  while true do
    local n=term.read("login: ",{history=false})
    if n and n~=""then
      local u=U.find(n)
      local pw=""
      if not u or u.hash~=""then pw=term.read("password: ",{mask="*",history=false})or""end
      if u and U.check(n,pw)then return u.name,u.home end
      term.write("Login incorrect\n")
      require("event").sleep(1)
    end
  end
end
return U
]]},
{"/sbin/init.lua",[[
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

term.write(string.format("\27[36m%s %s\27[0m  (%s, %dK RAM)\n",_OSNAME,_OSVERSION,_VERSION,math.floor(computer.totalMemory()/1024)))
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
]]},
}
local dirs={"/bin","/boot","/etc","/home","/lib","/mnt","/sbin","/tmp","/usr","/etc/rc.d","/usr/bin","/usr/lib"}
local BIOS=[[
-- ZenBIOS 1.0 - EEPROM firmware (must stay < 4096 bytes)
local c,p,u=component,computer,unicode
local I=c.invoke
local function F(t)return c.list(t)()end
local G,S,E=F("gpu"),F("screen"),F("eeprom")
local y=1
-- getBootAddress/setBootAddress are not part of the base API: keep them in EEPROM data
p.getBootAddress=function()return E and I(E,"getData")or""end
p.setBootAddress=function(a)return E and I(E,"setData",a)end
if G and S then I(G,"bind",S)I(G,"setResolution",50,16)end
local function cls()
 if G then I(G,"setBackground",0)I(G,"fill",1,1,50,16," ")end
 y=1
end
local function pr(s,f)
 if G then
  if y>16 then I(G,"copy",1,2,50,15,1,1)I(G,"fill",1,16,50,1," ")y=16 end
  I(G,"setForeground",f or 0xFFFFFF)I(G,"set",1,y,s)
 end
 y=y+1
end
local function pw(s,f)for i=1,math.max(#s,1),50 do pr(s:sub(i,i+49),f)end end
local function key()
 while 1 do
  local e,_,ch,co=p.pullSignal()
  if e=="key_down"then return ch,co end
 end
end
local function rl(m)
 local b=""
 while 1 do
  if G then
   if y>16 then pr("")y=16 end
   I(G,"setForeground",0xFFFFFF)I(G,"fill",1,y,50,1," ")I(G,"set",1,y,u.sub(m..b.."_",-50))
  end
  local ch,co=key()
  if co==28 then y=y+1 return b
  elseif co==14 then b=u.sub(b,1,-2)
  elseif ch>31 then b=b..u.char(ch)end
 end
end
local function rd(a,f)
 local h=I(a,"open",f)
 if not h then return end
 local d,s=""
 repeat s=I(a,"read",h,math.huge)d=d..(s or"")until not s
 I(a,"close",h)
 return d
end
local function run(d,n)
 local f,e=load(d,"="..n)
 if f then f,e=pcall(f)if f then return end end
 cls()pr("Error in "..n,0xFF0000)pw(tostring(e),0xFF8080)pr("Press any key",0x888888)
 p.beep(200,.3)key()
end
local function boot(a)
 local d=rd(a,"/init.lua")
 if d then
  if p.getBootAddress()~=a then p.setBootAddress(a)end
  run(d,"init")
 end
end
local function lua()
 cls()pr("Lua prompt - 'exit' to leave",0x00FFFF)
 while 1 do
  local l=rl("> ")
  if l=="exit"then return end
  local f,e=load("return "..l,"=lua")
  if not f then f,e=load(l,"=lua")end
  if f then
   local r=table.pack(pcall(f))
   if r[1]then for i=2,r.n do pw(tostring(r[i]))end else pw(tostring(r[2]),0xFF8080)end
  else pw(tostring(e),0xFF8080)end
 end
end
local function net()
 cls()
 local n=F("internet")
 if not n then pr("No internet card",0xFF0000)key()return end
 local d=(E and I(E,"getData")or""):match("^https?://%S+")or""
 local url=rl("URL"..(d~=""and" ["..d:sub(1,30).."]"or"")..": ")
 if url==""then url=d end
 if url==""then return end
 local h,e=I(n,"request",url)
 if not h then pw(tostring(e),0xFF0000)key()return end
 local t=""
 while 1 do
  local s,r=h.read()
  if not s then break end
  t=t..s
  if s==""then p.pullSignal(.1)end
 end
 h.close()
 run(t,"net")
end
local function menu(m)
 local s=1
 while 1 do
  cls()
  pr("ZenBIOS 1.0   Boot menu",0x00FF00)pr("")
  for i,e in ipairs(m)do pr((i==s and"> "or"  ")..e[1],i==s and 0xFFFF00 or 0xFFFFFF)end
  pr("")pr("Up/Down + Enter",0x888888)
  local _,co=key()
  if co==200 then s=(s-2)%#m+1
  elseif co==208 then s=s%#m+1
  elseif co==28 then return m[s]end
 end
end
cls()
pr("ZenBIOS 1.0",0x00FF00)
pr(math.floor(p.totalMemory()/1024).."K RAM",0x888888)
pr("Press any key for the boot menu...",0x888888)
local t,k=p.uptime()+1.5
repeat k=p.pullSignal(.1)=="key_down"until k or p.uptime()>t
local d=p.getBootAddress()
if not k and#d>0 then pcall(boot,d)end
local auto=not k
while 1 do
 local m={}
 for a in c.list("filesystem")do
  local ok,ex=pcall(I,a,"exists","/init.lua")
  if ok and ex and a~=p.tmpAddress()then
   m[#m+1]={(I(a,"getLabel")or"disk").." ("..a:sub(1,6)..")",function()boot(a)end}
  end
 end
 if auto and m[1]then auto=nil m[1][2]()end
 m[#m+1]={"Network boot",net}
 m[#m+1]={"Lua prompt",lua}
 m[#m+1]={"Reboot",function()p.shutdown(true)end}
 m[#m+1]={"Shutdown",function()p.shutdown()end}
 menu(m)[2]()
end
]]

local component=component or require("component")
local computer=computer or require("computer")
local function ask(q)io.write(q)return io.read()end
local function size(n)n=n or 0 if n>=1048576 then return string.format("%.1fM",n/1048576)end return string.format("%.0fK",n/1024)end
print("ZenOS 1.0 installer ("..#files.." files)")
local list={}
for a in component.list("filesystem")do
  if a~=computer.tmpAddress()then
    local px=component.proxy(a)
    list[#list+1]=px
    print(#list..") "..a:sub(1,8).."  "..(px.getLabel()or"-").."  "..size(px.spaceTotal())..(px.isReadOnly()and"  (read-only)"or""))
  end
end
local n=tonumber(ask("Target disk number: "))
local px=list[n or 0]
if not px then print("cancelled")return end
if px.isReadOnly()then print("disk is read-only")return end
if ask("Install ZenOS on "..px.address:sub(1,8).."? Existing ZenOS files will be overwritten. [y/N] ")~="y"then print("cancelled")return end
for _,d in ipairs(dirs)do px.makeDirectory(d)end
for i,f in ipairs(files)do
  local h,e=px.open(f[1],"w")
  if not h then error("cannot write "..f[1]..": "..tostring(e))end
  for p=1,#f[2],2048 do px.write(h,f[2]:sub(p,p+2047))end
  px.close(h)
  io.write("\r"..i.."/"..#files.." "..f[1].."          ")
end
print("\nfiles written")
local a=ask("Flash ZenBIOS to EEPROM? [Y/n] ")
if a~="n"and a~="N"then
  local ee=component.list("eeprom")()
  if ee then
    local e=component.proxy(ee)
    e.set(BIOS);e.setLabel("ZenBIOS 1.0")
    pcall(computer.setBootAddress,px.address)
    print("ZenBIOS flashed")
  else print("no EEPROM found")end
end
if ask("Reboot now? [Y/n] ")~="n"then computer.shutdown(true)end
