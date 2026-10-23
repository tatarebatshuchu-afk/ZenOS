local cmds={
{"ls [-la] [dir]","list files"},{"cd, pwd","change / show directory"},
{"cat, more, head, tail, wc","view files (more: pager)"},{"edit <file>","text editor (Ctrl+S save, Ctrl+Q quit)"},
{"cp [-r], mv, rm [-r]","copy, move, delete"},{"mkdir, touch","create dir / file"},
{"find [dir] 'mask'","search files by name"},{"grep [-ivnF] pat [f]","search text (Lua patterns)"},
{"tree [dir]","directory tree"},{"df, free, uptime","disk / memory / uptime"},
{"sysinfo","system information"},{"ps, kill <pid>","processes"},
{"components [type]","list OC components"},{"lua","Lua REPL"},
{"wget <url> [file]","download (internet card)"},{"mount, umount, label","filesystems"},
{"flash [-r] [file]","write / dump EEPROM BIOS"},{"install","install ZenOS to another disk"},
{"passwd [user]","set password (enables login)"},{"hostname, whoami, date","misc"},
{"resolution [w h]","screen resolution"},{"alias, export, set, history","shell"},
{"reboot, shutdown","power"},
}
print("ZenOS shell: | > >> < && || ; & * ? \"quotes\" $VAR, Tab completion, Ctrl+C/D")
for _,c in ipairs(cmds)do print(string.format("  %-26s %s",c[1],c[2]))end
