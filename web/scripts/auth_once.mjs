// Authenticate ONCE (patiently waiting out OTP cooldown/rate-limit) and cache the
// school-scoped session to /tmp/live-session.json for reuse by the browser sweeps.
import fs from 'node:fs';
const API='https://api.nikshaos.in/functions/v1/api';
const sleep=(ms)=>new Promise(r=>setTimeout(r,ms));
async function post(p,b,t){const r=await fetch(API+p,{method:'POST',headers:{'Content-Type':'application/json',...(t?{Authorization:`Bearer ${t}`}:{})},body:JSON.stringify(b)});return{status:r.status,json:await r.json().catch(()=>null)};}
async function get(p,t){const r=await fetch(API+p,{headers:t?{Authorization:`Bearer ${t}`}:{}});return{status:r.status,json:await r.json().catch(()=>null)};}
async function loginPatient(ph){
  for(let i=0;i<40;i++){
    const r=await post('/auth/login',{identifier:ph,type:'phone'});
    const d=r.json?.data; if(d?.otp&&d?.sessionId)return d;
    const code=r.json?.error?.code;
    if(code==='OTP_COOLDOWN'){process.stdout.write('  cooldown, wait 20s\n');await sleep(20000);continue;}
    if(code==='OTP_RATE_LIMITED'||r.status===429){process.stdout.write('  rate-limited, wait 45s\n');await sleep(45000);continue;}
    throw new Error('login: '+JSON.stringify(r.json?.error||r.status));
  }
  throw new Error('never cleared');
}
const ph='9876543210';
const {otp,sessionId}=await loginPatient(ph);
const v=await post('/auth/verify-otp',{identifier:ph,type:'phone',otp,sessionId});
const t0=v.json?.data?.accessToken||v.json?.data?.token;
const me0=await get('/auth/me',t0);const d0=me0.json?.data||{};
const schools=d0.schools||d0.availableSchools||d0.memberships||[];
const sid=(Array.isArray(schools)&&(schools[0]?.id||schools[0]?.schoolId))||d0.schoolId;
let token=t0; if(sid){const sw=await post('/auth/context/switch',{scope:'school',schoolId:sid},t0);token=sw.json?.data?.accessToken||t0;}
const me=(await get('/auth/me',token)).json?.data||{};
const session={id:String(me.id??'me'),name:String(me.name??'Signed in'),role:String(me.role??'schoolAdmin'),schoolName:String(me.schoolName??'Akshara'),schoolId:String(me.schoolId??sid??''),tenantId:String(me.organizationId??me.tenantId??''),token};
fs.writeFileSync('/tmp/live-session.json',JSON.stringify(session));
console.log('AUTH OK: role='+session.role+' school='+session.schoolId+' tokenLen='+token.length);
