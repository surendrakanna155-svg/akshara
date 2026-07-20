const BASE = 'https://akshara.veloraunisexsalon.com/functions/v1/api';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function post(p,b,t){const r=await fetch(BASE+p,{method:'POST',headers:{'Content-Type':'application/json',...(t?{Authorization:`Bearer ${t}`}:{})},body:JSON.stringify(b)});return{status:r.status,json:await r.json().catch(()=>null)};}
async function get(p,t){const r=await fetch(BASE+p,{headers:t?{Authorization:`Bearer ${t}`}:{}});return{status:r.status,json:await r.json().catch(()=>null)};}
async function loginCd(phone){for(let i=0;i<8;i++){const r=await post('/auth/login',{identifier:phone,type:'phone'});const d=r.json?.data;if(d?.otp&&d?.sessionId)return d;if(r.json?.error?.code==='OTP_COOLDOWN'){await sleep(20000);continue;}throw new Error('login '+JSON.stringify(r.json?.error||r.status));}throw new Error('cooldown');}
async function auth(phone){const{otp,sessionId}=await loginCd(phone);const v=await post('/auth/verify-otp',{identifier:phone,type:'phone',otp,sessionId});const d=v.json?.data;return d?.accessToken||d?.token;}
async function ctxSwitch(t){const me=await get('/auth/me',t);const d=me.json?.data||{};const schools=d.schools||d.availableSchools||d.memberships||[];const sid=(Array.isArray(schools)&&(schools[0]?.id||schools[0]?.schoolId))||d.schoolId;if(sid){const sw=await post('/auth/context/switch',{scope:'school',schoolId:sid},t);if(sw.json?.data?.accessToken)return sw.json.data.accessToken;}return t;}
function count(j){const d=j?.data;if(Array.isArray(d))return d.length;if(Array.isArray(d?.items))return d.items.length;if(Array.isArray(d?.kpis))return `${d.kpis.length}kpi`;return d&&typeof d==='object'?Object.keys(d).length+'keys':'—';}
const LISTS=['/sis/students','/hr/employees','/finance/collections','/finance/student-accounts','/library/catalog','/transport/routes','/admissions/leads','/finance/fee-structures','/academics/exams'];
const t0=await auth('9876543210');const t=await ctxSwitch(t0);
console.log('# live row counts (school context)');
for(const p of LISTS){const r=await get(p,t);console.log(`${String(r.status).padEnd(3)} ${p.padEnd(30)} rows=${r.status<300?count(r.json):('ERR '+(r.json?.error?.code||''))}`);}
