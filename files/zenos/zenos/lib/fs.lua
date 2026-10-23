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
