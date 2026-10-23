-- args.parse(argv, {x=true}) -> flags, positional   (x=true: option -x takes a value)
local M={}
function M.parse(argv,withval)
  local o,p={},{}
  local i=1
  while i<=#argv do
    local a=argv[i]
    if a=="--"then
      for j=i+1,#argv do p[#p+1]=argv[j]end
      break
    elseif a:sub(1,2)=="--"then
      local k,v=a:match("^%-%-([^=]+)=?(.*)$")
      o[k]=v~=""and v or true
    elseif a:sub(1,1)=="-"and#a>1 and not tonumber(a)then
      for c in a:sub(2):gmatch(".")do
        if withval and withval[c]then i=i+1;o[c]=argv[i]else o[c]=true end
      end
    else p[#p+1]=a end
    i=i+1
  end
  return o,p
end
return M
