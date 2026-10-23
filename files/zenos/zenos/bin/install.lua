-- install: copy the running ZenOS to another disk and (optionally) flash ZenBIOS
local fs,text=require("fs"),require("text")
local boot=computer.getBootAddress()
local list={}
for a in component.list("filesystem")do
  if a~=boot and a~=computer.tmpAddress()then
    local px=component.proxy(a)
    if not px.isReadOnly()then list[#list+1]=px end
  end
end
if#list==0 then io.stderr:write("no writable target disks found\n")return 1 end
for i,px in ipairs(list)do
  print(i..") "..px.address:sub(1,8).."  "..(px.getLabel()or"-").."  "..text.size(px.spaceTotal()))
end
io.write("Target disk number: ")
local px=list[tonumber(io.read())or 0]
if not px then print("cancelled")return 1 end
io.write("ZenOS files on "..px.address:sub(1,8).." will be overwritten. Continue? [y/N] ")
if io.read()~="y"then print("cancelled")return 1 end
local mp="/mnt/"..px.address:sub(1,3)
fs.mount(mp,px)
for _,d in ipairs{"bin","lib","sbin","etc","boot","usr"}do
  if fs.exists("/"..d)then
    print("copying /"..d)
    local ok,e=fs.copy("/"..d,mp.."/"..d)
    if not ok then io.stderr:write("error: "..tostring(e).."\n")return 1 end
  end
end
for _,d in ipairs{"home","mnt","tmp"}do fs.mkdir(mp.."/"..d)end
fs.copy("/init.lua",mp.."/init.lua")
io.write("Flash ZenBIOS to EEPROM? [Y/n] ")
local a=io.read()
if a~="n"and a~="N"then
  local ee=component.list("eeprom")()
  local bios=fs.readfile("/boot/bios.lua")
  if ee and bios then
    local e=component.proxy(ee)
    e.set(bios);e.setLabel("ZenBIOS")
    computer.setBootAddress(px.address)
    print("BIOS flashed")
  else print("no EEPROM or /boot/bios.lua missing")end
end
print("Done. Reboot to start from the new disk.")
