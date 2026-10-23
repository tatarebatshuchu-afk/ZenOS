local T={}
function T.trim(s)return(s:gsub("^%s+",""):gsub("%s+$",""))end
function T.split(s,sep)
  local t,i={},1
  while true do
    local j=s:find(sep,i,true)
    if not j then t[#t+1]=s:sub(i);return t end
    t[#t+1]=s:sub(i,j-1);i=j+#sep
  end
end
function T.size(n)
  n=n or 0
  local u,i={"B","K","M","G"},1
  while n>=1024 and i<#u do n=n/1024;i=i+1 end
  if i==1 then return string.format("%d%s",math.floor(n),u[i])end
  return string.format("%.1f%s",n,u[i])
end
function T.lines(d)
  local t={}
  if d==""then return t end
  for l in(d:gsub("\n$","").."\n"):gmatch("(.-)\n")do t[#t+1]=l end
  return t
end
function T.lpad(s,n)return string.rep(" ",n-unicode.len(s))..s end
function T.rpad(s,n)return s..string.rep(" ",n-unicode.len(s))end
return T
