const Notes = {
  async add(e) { e.preventDefault(); const form=e.target, f=Object.fromEntries(new FormData(form)); const image=await App.imageData(form.querySelector('[name="image"]')); delete f.image; DB.update({notes:[...DB.user().notes,{id:DB.uid(),...f,image,favorite:false,createdAt:Date.now()}]}); App.closeModal(); App.render(); },
  remove(id) { DB.update({notes:DB.user().notes.filter(n=>n.id!==id)}); App.render(); },
  favorite(id) { DB.update({notes:DB.user().notes.map(n=>n.id===id?{...n,favorite:!n.favorite}:n)}); App.render(); },
  async addMistake(e) { e.preventDefault(); const form=e.target, f=Object.fromEntries(new FormData(form)); const image=await App.imageData(form.querySelector('[name="image"]')); delete f.image; DB.update({mistakes:[...DB.user().mistakes,{id:DB.uid(),...f,image,reviewed:false,createdAt:Date.now()}]}); App.closeModal(); App.render(); },
  review(id) { DB.update({mistakes:DB.user().mistakes.map(m=>m.id===id?{...m,reviewed:!m.reviewed}:m)}); App.render(); }
};
