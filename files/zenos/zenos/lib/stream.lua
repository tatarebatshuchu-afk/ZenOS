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
