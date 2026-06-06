# Test Coverage Guide

**Project:** Akshara ERP  
**Target:** 80%+ line coverage (long-term)  
**CI:** `flutter test --coverage` on every push and pull request

---

## Generate Coverage

From the repository root:

```bash
flutter pub get
flutter test --coverage
```

This writes `coverage/lcov.info` (gitignored; regenerated in CI and locally).

---

## View Coverage

### Terminal summary (requires `lcov`)

```bash
# macOS
brew install lcov

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### VS Code / Cursor

Install the **Coverage Gutters** extension, then run **Coverage Gutters: Display Coverage** after generating `lcov.info`.

### CI artifacts

The GitHub Actions workflow verifies `coverage/lcov.info` exists after each test run. Upload as an artifact in a future workflow step if team review is needed.

---

## Minimum Target

| Milestone | Target | Status |
|-----------|--------|--------|
| v0.5.1 stabilization | Establish CI coverage artifact | ✅ CI generates `lcov.info` |
| v0.5.1 baseline | **76.6%** line coverage (9,569 / 12,499 lines) | Measured June 2026 |
| v0.6+ | 80% line coverage | Gap: error/empty branches, placeholder handlers |
| v1.0 | **80%+** sustained | Long-term goal |

Focus coverage expansion on:

- Riverpod providers (mock state flags, filters, integrations)
- Router smoke paths per module
- Shared widget edge states (loading, empty, error)
- Golden dashboards (macOS only)

---

## Golden Tests (macOS)

Golden tests live in `test/golden/` and run only on macOS (`@TestOn('mac-os')`) to avoid Linux/macOS font rendering drift in CI.

```bash
# Update golden PNGs after intentional UI changes
flutter test test/golden --update-goldens
```

Golden PNGs are committed under `test/golden/goldens/`.

---

## CI Commands

The workflow `.github/workflows/flutter_ci.yml` runs:

1. `flutter pub get`
2. `flutter analyze` — fails on any issue
3. `flutter test --coverage` — fails on test failures; golden tests skipped on Ubuntu
