// Single patient auth: long quiet windows, minimal requests, to let the OTP
// per-phone cap fully reset. Caches school-scoped session on success.
import fs from 'node:fs';
const API='https://api.nikshaos.in/functions/v1/api';
const sleep=(ms)=>new Promise(r=>setTimeout(r,ms));
async function post(p,b,t){const r=await fetch(API+p,{method:'POST',headers:{'Content-Type':'application/json',...(t?{Authorization:`Bearer ${t}`}:{})},body:JSON.stringify(b)});return{status:r.status,json:await r.json().catch(()=>null)};}
async function get(p,t){const r=await fetch(API+p,{headers:t?{Authorization:`Bearer ${t}`}:{}});return{status:r.status,json:await r.json().catch(()=>null)};}
const waits=[1500000, 900000, 900000, 900000]; // 25,15,15,15 min between the (few) attempts
let d;
for(let i=0;i<waits.length;i++){
  process.stdout.write(`quiet ${waits[i]/60000}min (no requests)...\n`);
  await sleep(waits[i]);
  const r=await post('/auth/login',{identifier:'9876543210',type:'phone'});
  d=r.json?.data;
  if(d?.otp&&d?.sessionId){process.stdout.write('login OK\n');break;}
  process.stdout.write(`  attempt ${i+1} → ${r.json?.error?.code||r.status}\n`);
  d=null;
}
if(!d?.otp) throw new Error('OTP cap did not reset within the cooldown budget');
const v=await post('/auth/verify-otp',{identifier:'9876543210',type:'phone',otp:d.otp,sessionId:d.sessionId});
const t0=v.json?.data?.accessToken||v.json?.data?.token;
const me0=await get('/auth/me',t0);const d0=me0.json?.data||{};const schools=d0.schools||d0.availableSchools||[];const sid=(Array.isArray(schools)&&(schools[0]?.id||schools[0]?.schoolId))||d0.schoolId;
let token=t0; if(sid){const sw=await post('/auth/context/switch',{scope:'school',schoolId:sid},t0);token=sw.json?.data?.accessToken||t0;}
const me=(await get('/auth/me',token)).json?.data||{};
const session={id:String(me.id??'me'),name:String(me.name??'Signed in'),role:String(me.role??'schoolAdmin'),schoolName:String(me.schoolName??'Akshara'),schoolId:String(me.schoolId??sid??''),tenantId:String(me.organizationId??me.tenantId??''),token};
fs.writeFileSync('/tmp/live-session.json',JSON.stringify(session));
console.log('AUTH OK: role='+session.role+' school='+session.schoolId+' tokenLen='+token.length);
