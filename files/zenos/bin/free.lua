local text=require("text")
local t,f=computer.totalMemory(),computer.freeMemory()
print("RAM:    "..text.size(t-f).." used / "..text.size(t))
print(string.format("Energy: %d / %d",computer.energy(),computer.maxEnergy()))
