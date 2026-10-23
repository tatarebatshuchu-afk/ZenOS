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
