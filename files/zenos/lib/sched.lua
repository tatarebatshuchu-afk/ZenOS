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
