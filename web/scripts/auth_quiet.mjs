import fs from 'node:fs';
const API='https://akshara.veloraunisexsalon.com/functions/v1/api';
const sleep=(ms)=>new Promise(r=>setTimeout(r,ms));
async function post(p,b,t){const r=await fetch(API+p,{method:'POST',headers:{'Content-Type':'application/json',...(t?{Authorization:`Bearer ${t}`}:{})},body:JSON.stringify(b)});return{status:r.status,json:await r.json().catch(()=>null)};}
async function get(p,t){const r=await fetch(API+p,{headers:t?{Authorization:`Bearer ${t}`}:{}});return{status:r.status,json:await r.json().catch(()=>null)};}
process.stdout.write('quiet 480s (no requests) to reset the OTP window...\n');
await sleep(480000);
let d;
for(let i=0;i<10;i++){
  const r=await post('/auth/login',{identifier:'9876543210',type:'phone'});
  d=r.json?.data; if(d?.otp&&d?.sessionId){process.stdout.write('login OK\n');break;}
  const code=r.json?.error?.code||r.status;
  process.stdout.write('  attempt '+(i+1)+' → '+code+', wait 90s\n');
  await sleep(90000);
}
if(!d?.otp) throw new Error('still limited after quiet window');
const v=await post('/auth/verify-otp',{identifier:'9876543210',type:'phone',otp:d.otp,sessionId:d.sessionId});
const t0=v.json?.data?.accessToken||v.json?.data?.token;
const me0=await get('/auth/me',t0);const d0=me0.json?.data||{};const schools=d0.schools||d0.availableSchools||[];const sid=(Array.isArray(schools)&&(schools[0]?.id||schools[0]?.schoolId))||d0.schoolId;
let token=t0; if(sid){const sw=await post('/auth/context/switch',{scope:'school',schoolId:sid},t0);token=sw.json?.data?.accessToken||t0;}
const me=(await get('/auth/me',token)).json?.data||{};
const session={id:String(me.id??'me'),name:String(me.name??'Signed in'),role:String(me.role??'schoolAdmin'),schoolName:String(me.schoolName??'Akshara'),schoolId:String(me.schoolId??sid??''),tenantId:String(me.organizationId??me.tenantId??''),token};
fs.writeFileSync('/tmp/live-session.json',JSON.stringify(session));
console.log('AUTH OK: role='+session.role+' school='+session.schoolId+' tokenLen='+token.length);
