local s=require("sched")
return{pull=s.pull,listen=s.listen,ignore=s.ignore,timer=s.timer,cancel=s.cancel,
  push=computer.pushSignal,sleep=s.sleep}
