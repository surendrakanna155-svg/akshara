# Operational procedure — face match threshold calibration

**Who runs this:** whoever is standing up the first pilot school, with a member
of that school's staff present.
**When:** once per deployment, before face check-in is enabled for real
attendance. Repeat if the capture pipeline, camera guidance or model changes.
**How long:** about 30 minutes of capture plus a few minutes of analysis.

## Why this exists

The shipped default is **0.40**, taken from published ArcFace-family practice
(OpenCV's SFace ships 0.363). It is a defensible starting point, **not a
measured operating point for your staff, your cameras and your lighting.**

Getting it wrong is not symmetric:

- **Too high** → genuine staff are rejected every morning. Safe, but it presents
  as an outage and destroys trust in the feature on day one.
- **Too low** → one staff member can check in as another. That is payroll fraud,
  and the audit trail will show it as a legitimate verified check-in.

So the threshold is set from data, not from a default.

## Step 1 — collect captures

Enrol **at least 5 staff members**, with **3+ captures each**, taken across
**different sessions** — not three photos in a row.

Vary deliberately, because this variation is what the threshold has to survive:

- morning and afternoon light; indoor and near a window
- with and without glasses, if the person wears them
- the natural range of distance and angle people actually use at the gate

Save them as aligned 112×112 crops — exactly what the app sends — laid out one
directory per person:

```
captures/
  staff_7f3a1c/   cap_1.png  cap_2.png  cap_3.png
  staff_0b92de/   cap_1.png  cap_2.png  cap_3.png
  ...
```

> **Use opaque staff IDs as directory names, never names.** The tool writes a
> CSV of who-resembles-whom; keyed by name that is a file you would rather not
> have created. The IDs also keep the artefact usable under DPDP as pseudonymous
> data rather than a directory of identified biometrics.

**Delete the captures once calibration is done.** They are raw biometric data
with no further purpose — the enrolment references already live in the database,
and the CSV of scores is the durable record.

## Step 2 — run the tool

```bash
cd /opt/akshara/face-inference
python3 calibrate.py --captures ./captures --out calibration_$(date +%F).csv
```

It scores every same-person pair (**genuine**) and every cross-person pair
(**impostor**) through the **running service**, so the numbers come from the
exact path production uses — including face-presence validation and int8
quantisation. Calibrating against any other code path would produce a threshold
that does not hold in production.

## Step 3 — read the verdict

### ✅ Separable

```
  ✅ SEPARABLE — genuine and impostor distributions do not overlap.
     gap: impostor max +0.3102 → genuine min +0.6488
     RECOMMENDED THRESHOLD: 0.480
```

The recommendation sits in the middle of the gap, so lighting drift (which
pushes genuine scores down) and a lookalike (which pushes impostor scores up)
both have room before either becomes an error.

Apply it on the edge service and restart:

```
FACE_MATCH_MIN_SIMILARITY=0.480
```

Note the clamp band is **[0.25, 0.99]** (`face_match.ts`). A value outside it is
clamped silently, so if the data genuinely calls for something lower, change
`MIN_SIMILARITY_THRESHOLD` rather than setting a value that will not take
effect.

### ⚠️ Overlap

```
  ⚠️  OVERLAP — some impostor pairs score at or above the weakest genuine pair.
```

**Do not simply pick a number.** Overlap almost always means the capture
pipeline, not the threshold:

- inconsistent alignment or crop geometry between captures
- enrolment in very different lighting from verification
- a mislabelled directory — two folders that are actually the same person
- too few captures, so one bad capture dominates the genuine minimum

Fix the captures and re-run. Only if overlap persists across a clean re-capture
should you choose from the FAR table the tool prints, and in that case bias
towards **false reject** — a rejected staff member uses the audited manual
request; an accepted impostor creates a false payroll record.

## Step 4 — record and re-check

- Commit the CSV (scores only, no images) to the deployment record.
- Note the chosen threshold, the date, and the school in the handover.
- Re-run if the camera guidance, crop geometry, or the model changes. A model
  change also requires bumping the model tag, which forces re-enrolment — the
  server refuses to compare across tags.

## What the tool will not do

It will not tell you the false-accept rate against the general population.
Impostor pairs come only from the staff you enrolled, so a school of 40 gives
you 40 identities' worth of evidence, not a population study. That is the right
scope for 1:1 verification — the system only ever compares a person against
their own reference — but it does mean the number is a school-level operating
point, not a published accuracy claim.
