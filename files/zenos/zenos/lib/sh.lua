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
