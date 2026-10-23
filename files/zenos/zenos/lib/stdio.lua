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
