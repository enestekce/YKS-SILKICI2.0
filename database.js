const DB = {
  key: 'yks-silkici-premium-v2',
  users() { return JSON.parse(localStorage.getItem(this.key + '-users') || '[]'); },
  saveUsers(users) { localStorage.setItem(this.key + '-users', JSON.stringify(users)); },
  current() { return localStorage.getItem(this.key + '-session'); },
  setCurrent(username) { localStorage.setItem(this.key + '-session', username); },
  logout() { localStorage.removeItem(this.key + '-session'); },
  user() { return this.users().find(u => u.username === this.current()); },
  update(data) { const users=this.users(), i=users.findIndex(u=>u.username===this.current()); if(i<0)return; users[i]={...users[i],...data}; this.saveUsers(users); },
  blank(name, username, password) { return { name, username, password, createdAt:Date.now(), tasks:[], notes:[], mistakes:[], exams:[], subjects:{}, goals:{school:'',targetNet:0,currentNet:0}, studyLogs:[], pomodoro:null, stopwatch:{startedAt:null,elapsed:0,active:false}, weekly:{}, weeklySaved:null, badges:[] }; },
  uid() { return Date.now().toString(36)+Math.random().toString(36).slice(2,7); }
};
