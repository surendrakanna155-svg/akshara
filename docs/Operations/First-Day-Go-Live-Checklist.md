# First-Day Go-Live Checklist

**Version:** 1.0 (v1.0-rc1)  
**When:** Opening day of first real-school pilot  
**Prerequisite:** [`School-Setup-Checklist.md`](./School-Setup-Checklist.md) complete

---

## T-1 (evening before)

- [ ] Confirm `GET /health/ready` → 200
- [ ] Confirm 213/213 tenant probes pass
- [ ] Backup snapshot taken and labeled `first-school-go-live-YYYY-MM-DD`
- [ ] School admin + principal contact numbers verified
- [ ] SMS/OTP delivery tested on production (not dev-mode OTP in API body)
- [ ] Support channel announced to school (phone / WhatsApp group)

---

## Morning — before gates open

| Time | Task | Owner | Done |
|------|------|-------|:----:|
| | Admin login — ERP web | School admin | ☐ |
| | Principal login — ERP web | Principal | ☐ |
| | Verify SIS student count matches import | Admin | ☐ |
| | Verify class lists for each section | Principal | ☐ |
| | Teacher logins — spot-check 3 teachers | IT / admin | ☐ |
| | Parent login — spot-check 3 parents | IT / admin | ☐ |

---

## During school hours

### Attendance

- [ ] Homeroom teachers open Teacher app / attendance screen
- [ ] Mark attendance for assigned class (draft → submit)
- [ ] Admin verifies submitted session in ERP
- [ ] One parent confirms attendance visible on Parent app

### Communications

- [ ] Welcome broadcast to `all_parents` (or `all_teachers` first)
- [ ] Process notification queue
- [ ] Confirm ≥1 parent received notification

### Fees (if applicable)

- [ ] Fee desk can list outstanding invoices
- [ ] Record at least one walk-in cash collection
- [ ] Parent sees updated balance / receipt

### Incidents

- [ ] Any failure logged in Pilot Issue Tracker within 1 hour
- [ ] Rollback **not** triggered without Release Manager approval

---

## End of day

- [ ] Attendance submitted for all active classes (or documented exceptions)
- [ ] No open **Critical** or **High** pilot issues unresolved
- [ ] Daily summary: students present, collections total, OTP failures count
- [ ] Backup / PITR checkpoint confirmed

---

## Escalation

| Symptom | Action |
|---------|--------|
| OTP not received | Check `AUTH_OTP_DEV_MODE`, Twilio credentials, phone format |
| Import partial failure | Review job `report.failures`; rollback job if needed |
| Parent cannot see child | Verify `student_guardians` link; parent used correct school scope |
| 502 on broadcast | Retry once; if persistent, log PILOT issue |
| Auth outage all users | See [`Rollback-Checklist.md`](./Rollback-Checklist.md) |

---

## Sign-off

| Role | Name | Date | Day-1 status |
|------|------|------|--------------|
| School admin | | | ☐ Accept ☐ Issues |
| Release manager | | | ☐ Accept ☐ Issues |
| Pilot school lead | | | ☐ Accept ☐ Issues |
