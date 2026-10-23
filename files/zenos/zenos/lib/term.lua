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
