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
