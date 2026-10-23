local s=math.floor(computer.uptime())
print(string.format("up %dh %02dm %02ds",s//3600,s%3600//60,s%60))
