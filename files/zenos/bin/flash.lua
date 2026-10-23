-- flash [file]       write BIOS to EEPROM (default /boot/bios.lua)
-- flash -r [file]    dump the current EEPROM code to a file
local fs,args=require("fs"),require("args")
local o,p=args.parse({...})
local ee=component.list("eeprom")()
if not ee then io.stderr:write("flash: no EEPROM\n")return 1 end
local e=component.proxy(ee)
if o.r then
  local path=p[1]or"bios_dump.lua"
  fs.writefile(path,e.get())
  print("saved to "..path)
  return 0
end
local path=p[1]or"/boot/bios.lua"
local d,err=fs.readfile(path)
if not d then io.stderr:write("flash: "..tostring(err).."\n")return 1 end
if#d>e.getSize()then io.stderr:write("flash: file too big ("..#d.." > "..e.getSize()..")\n")return 1 end
io.write("Flash "..path.." ("..#d.." bytes) to EEPROM? [y/N] ")
if io.read()~="y"then print("aborted")return 1 end
e.set(d)
e.setLabel("ZenBIOS")
print("done - reboot to apply")
