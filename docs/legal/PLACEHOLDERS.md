# NIKSHA OS — Legal Placeholders (Owner Action Required)

> This file is the **single source of truth** for every owner-supplied value used
> across the documents in `docs/legal/`. Each value appears in the policies as a
> bracketed token like `NIKSHA Technologies Pvt. Ltd.`. Before the legal documents are
> published or the app is submitted for production release, the owner must fill in
> every row below and replace the matching tokens in the policy files.
>
> To find every place a token is used:
> ```
> grep -rn "\[LEGAL ENTITY NAME\]" docs/legal/
> ```

**Status (2026-07-28):** 🟡 **PARTIALLY COMPLETE.** Everything that could be decided
without the domain and company registration has been filled in and removed from the
policies. **Every token still listed below is blocked on one of exactly two owner
actions — buying the domain, or completing company registration.** Nothing else in the
legal pack is waiting on engineering.

| Decided | Value |
|---|---|
| Product name | **NIKSHA OS** |
| Legal entity | **NIKSHA Technologies Pvt. Ltd.** |
| Entity type | Private Limited Company |
| Copyright year | 2026 |

⚠️ **Governing law city/state are deliberately still blank.** They must match the
registered office in the incorporation certificate — guessing "Hyderabad / Telangana"
from the demo data would put an unverified jurisdiction into a binding contract.

| Token | Meaning | Example | Value (owner to fill) |
|---|---|---|---|
| `NIKSHA Technologies Pvt. Ltd.` | Registered legal entity that operates NIKSHA OS | "NIKSHA Technologies Pvt. Ltd." | `TODO` |
| `Private Limited Company` | Company / LLP / proprietorship / partnership | "Private Limited Company" | `TODO` |
| `[CIN / REG NO]` | Company / LLP registration number (CIN, etc.) | "U72900TS2025PTC000000" | `TODO` |
| `[REGISTERED ADDRESS]` | Full registered office address | "Plot 1, Hitech City, Hyderabad, Telangana 500081, India" | `TODO` |
| `[SUPPORT EMAIL]` | General product / customer support | "support@akshara.app" | `TODO` |
| `[PRIVACY EMAIL]` | Privacy / data-protection contact (DPDP) | "privacy@akshara.app" | `TODO` |
| `[GRIEVANCE OFFICER NAME]` | Named Grievance Officer (IT Rules 2021 / DPDP) | "Ms. A. Sharma" | `TODO` |
| `[GRIEVANCE OFFICER DESIGNATION]` | Their designation | "Grievance Officer" | `TODO` |
| `[GRIEVANCE EMAIL]` | Grievance Officer contact email | "grievance@akshara.app" | `TODO` |
| `[SECURITY EMAIL]` | Security / responsible-disclosure inbox | "security@akshara.app" | `TODO` |
| `[WEBSITE URL]` | Public marketing/website root | "https://akshara.app" | `TODO` |
| `[POLICY HOST BASE URL]` | Public HTTPS base where policies are hosted | "https://akshara.veloraunisexsalon.com" | `https://akshara.veloraunisexsalon.com` (current) |
| `[GOVERNING LAW CITY]` | City whose courts have jurisdiction | "Hyderabad" | `TODO` |
| `[GOVERNING LAW STATE]` | State for governing law | "Telangana" | `TODO` |
| `2026` | Year(s) for the copyright notice | "2026" | `2026` |
| `[PHONE / SUPPORT NUMBER]` | Optional support phone number | "+91 ..." | `TODO (optional)` |

## Notes for the owner

1. **Hosting.** The Privacy Policy (at minimum) must be reachable at a public
   HTTPS URL, and the **same** URL must be entered in the Google Play Console
   "Privacy Policy" field and in
   [`lib/core/legal/legal_links.dart`](../../lib/core/legal/legal_links.dart).
   The current configured host is `https://akshara.veloraunisexsalon.com`.
2. **Grievance Officer** is a legal requirement for an intermediary/data
   fiduciary operating in India. Name a real person and a monitored inbox.
3. **Data Protection Officer (DPO).** Only a *Significant* Data Fiduciary must
   appoint a DPO. NIKSHA OS is unlikely to be classified as one initially, so a
   Grievance/Privacy contact is sufficient — but revisit if the Data Protection
   Board notifies NIKSHA OS as an SDF.
4. The brand name **"NIKSHA OS" / "NIKSHA OS"** is fixed and is **not** a
   placeholder. Only the *legal entity* behind it needs to be filled in.
