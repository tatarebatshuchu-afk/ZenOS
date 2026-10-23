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
