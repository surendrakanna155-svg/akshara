# Akshara Autonomous QA Platform

Permanent Maestro-based regression infrastructure for pre-release validation.

## Folder structure

```
qa/
├── maestro/
│   ├── config.yaml          # appId + default env vars
│   └── flows/_shared/       # Reusable subflows (login, ERP nav)
├── journeys/                # Maestro journey YAML files (24 flows)
├── inventory/               # Generated route inventory (routes.json)
├── screenshots/             # Per-run screenshots (gitignored contents)
├── reports/                 # Per-run JUnit + coverage summaries
├── run_all_qa.sh            # Full regression (Flutter gates + Maestro)
└── generate_report.sh       # Aggregate coverage + findings
```

## Prerequisites

1. **Maestro CLI** — `scripts/qa/setup_maestro.sh`
2. **Android device or emulator** — `flutter emulators --launch Medium_Phone_API_36.0`
3. **QA APK** (demo auth, mock data) — `scripts/qa/build_qa_apk.sh`

Add Maestro to PATH:

```bash
export PATH="${HOME}/.maestro/bin:${PATH}"
```

## One-command full regression

```bash
./qa/run_all_qa.sh
```

Options (environment variables):

| Variable | Default | Description |
|----------|---------|-------------|
| `SMOKE_ONLY=1` | off | Run only `smoke_launch` + `smoke_otp_back` |
| `SKIP_FLUTTER=1` | off | Skip `flutter analyze` / `flutter test` |
| `SKIP_MAESTRO=1` | off | Skip Maestro (inventory + Flutter only) |
| `BUILD_APK=1` | off | Build and install QA APK before Maestro |

Smoke-only (fast gate):

```bash
SMOKE_ONLY=1 BUILD_APK=1 ./qa/run_all_qa.sh
```

## QA build profile

Demo auth enabled for deterministic OTP:

- Mobile OTP: `123456`
- Staff OTP: `654321`

```bash
./scripts/qa/build_qa_apk.sh
adb install -r build/app/outputs/flutter-apk/app-profile.apk
```

## Journey catalog

| Category | Count | Examples |
|----------|------:|---------|
| Smoke | 2 | `smoke_launch`, `smoke_otp_back` |
| Personas | 9 | `persona_parent`, `persona_super_admin`, `persona_finance` |
| Workflows | 13 | `workflow_attendance`, `workflow_fees`, `workflow_analytics` |

Run a single journey:

```bash
maestro test -c qa/maestro/config.yaml qa/journeys/persona_parent.yaml
```

## Reports

After each run:

- `qa/reports/<timestamp>/coverage_summary.json` — coverage metrics
- `qa/reports/<timestamp>/findings.json` — failures (navigation, crashes)
- `qa/reports/<timestamp>/maestro.junit.xml` — CI-compatible output
- `qa/screenshots/<timestamp>/` — journey screenshots

Regenerate report from existing run:

```bash
./qa/generate_report.sh 20260612_120000 pass
```

## Route inventory

```bash
python3 scripts/qa/extract_route_inventory.py
# → qa/inventory/routes.json (189 static paths)
```

Flutter `router_smoke_test.dart` validates **123** ERP/mobile routes in widget tests.

## Documentation

- Setup guide: `docs/Testing/Maestro-Setup.md`
- Release notes: `docs/Releases/v18.1-Autonomous-QA-Platform.md`
