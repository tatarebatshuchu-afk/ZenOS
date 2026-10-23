-- passwd [user]  (creates the user if missing; empty password = no password)
local users,term=require("users"),require("term")
local name=(...)or os.getenv("USER")or"root"
local a=term.read("New password for "..name..": ",{mask="*",history=false})
if a==nil then return 1 end
local b=term.read("Repeat: ",{mask="*",history=false})
if a~=b then io.stderr:write("passwords differ\n")return 1 end
users.set(name,a)
print("password updated"..(a==""and" (empty = no password)"or""))
