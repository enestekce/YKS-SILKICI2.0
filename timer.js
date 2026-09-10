const Stopwatch = {
  interval:null, lastPresence:0,
  state(){return DB.user()?.stopwatch||{startedAt:null,elapsed:0,active:false}},
  saveState(data){DB.update({stopwatch:{...this.state(),...data}})},
  start(){const s=this.state();if(s.active)return;this.saveState({startedAt:Date.now(),active:true});this.lastPresence=Date.now();window.Community?.syncPresence();this.run();App.render()},
  stop(){const s=this.state();if(!s.active)return;this.saveState({elapsed:this.value()*1000,startedAt:null,active:false});window.Community?.syncPresence();clearInterval(this.interval);App.render()},
  reset(){clearInterval(this.interval);this.saveState({startedAt:null,elapsed:0,active:false});window.Community?.syncPresence();App.render()},
  save(){const seconds=this.value();this.stop();const minutes=Math.max(1,Math.round(seconds/60));DB.update({studyLogs:[...DB.user().studyLogs,{id:DB.uid(),minutes,date:new Date().toISOString()}],stopwatch:{startedAt:null,elapsed:0,active:false}});window.Community?.syncPresence();App.render();App.toast(`${minutes} dakika çalışma kaydedildi.`)},
  value(){const s=this.state();return Math.floor(((+s.elapsed||0)+(s.active?Date.now()-(+s.startedAt||Date.now()):0))/1000)},
  run(){clearInterval(this.interval);if(!this.state().active)return;this.interval=setInterval(()=>{if(!this.state().active)return clearInterval(this.interval);const e=document.querySelector('#stopwatch-display');if(e)e.textContent=App.time(this.value());if(Date.now()-this.lastPresence>=15000){this.lastPresence=Date.now();window.Community?.syncPresence()}},300)}
};
