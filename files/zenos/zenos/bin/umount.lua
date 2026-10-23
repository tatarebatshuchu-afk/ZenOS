local fs=require("fs")
if not fs.umount((...)or"")then io.stderr:write("umount: not a mount point\n")return 1 end
