const Tasks = {
  list(filter='all') { let a=DB.user().tasks||[]; if(filter==='active')a=a.filter(t=>!t.done); if(filter==='done')a=a.filter(t=>t.done); return a.sort((a,b)=>Number(a.done)-Number(b.done)||new Date(a.date)-new Date(b.date)); },
  add(e) { e.preventDefault(); const f=Object.fromEntries(new FormData(e.target)); DB.update({tasks:[...DB.user().tasks,{id:DB.uid(),...f,done:false}]}); App.closeModal(); App.render(); App.toast('Görev planına eklendi.'); },
  toggle(id) { const tasks=DB.user().tasks.map(t=>t.id===id?{...t,done:!t.done,doneAt:!t.done?Date.now():null}:t); DB.update({tasks}); App.render(); },
  remove(id) { DB.update({tasks:DB.user().tasks.filter(t=>t.id!==id)}); App.render(); },
  edit(id) { const t=DB.user().tasks.find(t=>t.id===id); App.modal(`Görevi düzenle`, `<form onsubmit="Tasks.saveEdit(event,'${id}')"><label>Görev<input name="title" required value="${App.escape(t.title)}"></label><label>Ders<input name="subject" value="${App.escape(t.subject||'')}"></label><label>Tarih<input type="date" name="date" value="${t.date||''}"></label><label>Öncelik<select name="priority"><option ${t.priority==='Normal'?'selected':''}>Normal</option><option ${t.priority==='Önemli'?'selected':''}>Önemli</option><option ${t.priority==='Acil'?'selected':''}>Acil</option></select></label><button class="btn primary wide">Kaydet</button></form>`); },
  saveEdit(e,id) { e.preventDefault(); const f=Object.fromEntries(new FormData(e.target)); DB.update({tasks:DB.user().tasks.map(t=>t.id===id?{...t,...f}:t)}); App.closeModal(); App.render(); }
};
