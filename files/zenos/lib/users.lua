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
