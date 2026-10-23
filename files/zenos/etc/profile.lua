-- Runs after every login. Put your aliases and variables here.
local sh=require("sh")
sh.aliases.ll="ls -l"
sh.aliases.la="ls -a"
sh.aliases[".."]="cd .."
sh.aliases.cls="clear"
sh.aliases.halt="shutdown"
-- os.setenv("PS1","\\u@\\h:\\w\\$ ")   -- custom prompt: \u user, \h host, \w dir, \$ # or $
