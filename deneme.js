const Exams = {
  calc(f) { return ['turkce','mat','fen','sosyal'].reduce((x,k)=>x+(+f[k+'D']||0)-(+f[k+'Y']||0)/4,0); },
  add(e) { e.preventDefault(); const f=Object.fromEntries(new FormData(e.target)); const exam={id:DB.uid(),...f,total:this.calc(f),createdAt:Date.now()}; DB.update({exams:[...DB.user().exams,exam]}); const hit=Analysis.weakTopics().find(x=>x.subject===f.weakSubject&&x.topic===f.weakTopic); App.closeModal(); App.render(); App.toast(hit&&hit.count>=3?`Uyarı: ${f.weakTopic} konusu ${hit.count} kez tekrar etti.`:'Deneme sonucu kaydedildi.'); },
  remove(id) { DB.update({exams:DB.user().exams.filter(x=>x.id!==id)}); App.render(); }
};
