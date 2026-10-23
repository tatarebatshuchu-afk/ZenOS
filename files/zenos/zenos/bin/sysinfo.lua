local term,fs,text=require("term"),require("fs"),require("text")
local function c(n,s)return"\27["..n.."m"..s.."\27[0m"end
local logo={[[ _____              ___  ____  ]],[[|__  /___ _ __    / _ \/ ___| ]],
[[  / // _ \ '_ \  | | | \___ \ ]],[[ / /|  __/ | | | | |_| |___) |]],[[/____\___|_| |_|  \___/|____/ ]]}
for _,l in ipairs(logo)do print(c(36,l))end
local w,h=term.size()
local n=0
for _ in component.list()do n=n+1 end
local t,f=computer.totalMemory(),computer.freeMemory()
local s=math.floor(computer.uptime())
local function row(k,v)print(c(32,text.rpad(k,9))..v)end
print()
row("User",(os.getenv("USER")or"?").."@"..(os.getenv("HOSTNAME")or"zen"))
row("OS",_OSNAME.." ".._OSVERSION)
row("Lua",_VERSION)
row("Uptime",string.format("%dh %02dm %02ds",s//3600,s%3600//60,s%60))
row("Memory",text.size(t-f).." / "..text.size(t))
row("Energy",math.floor(computer.energy()).." / "..math.floor(computer.maxEnergy()))
row("Screen",w.."x"..h)
row("Devices",n.." components")
