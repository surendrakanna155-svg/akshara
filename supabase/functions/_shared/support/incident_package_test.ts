import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  assembleDeterministic,
  categorize,
  safeParseEnrichment,
  suggestSeverity,
} from "./incident_package.ts";
import type { Diagnostics } from "./evidence_collector.ts";

const NO_DIAG: Diagnostics = {
  failingCorrelationId: null,
  apiErrorCount: 0,
  topErrorStatus: null,
  topErrorPath: null,
  hasAppVersion: true,
  signals: [],
};

function diag(signals: string[], extra: Partial<Diagnostics> = {}): Diagnostics {
  return { ...NO_DIAG, signals, ...extra };
}

Deno.test("categorize picks permission_rbac from a 403 signal even without keywords", () => {
  const r = categorize(
    { title: "Screen not working", description: "nothing happens", reporterRole: "teacher", moduleKey: "sis", screenRoute: null, platform: "android", appVersion: "1.0" },
    diag(["recent 403 (permission/RBAC)"]),
  );
  assertEquals(r.category, "permission_rbac");
});

Deno.test("categorize picks login_auth from keyword", () => {
  const r = categorize(
    { title: "Cannot log in", description: "OTP never arrives", reporterRole: "principal", moduleKey: null, screenRoute: null, platform: "ios", appVersion: "1.0" },
    NO_DIAG,
  );
  assertEquals(r.category, "login_auth");
});

Deno.test("categorize picks payment_billing from keyword", () => {
  const r = categorize(
    { title: "Fee payment failed", description: "the invoice shows twice", reporterRole: "financeAdmin", moduleKey: "finance", screenRoute: null, platform: "web", appVersion: "1.0" },
    NO_DIAG,
  );
  assertEquals(r.category, "payment_billing");
});

Deno.test("categorize falls back to unknown with no signal", () => {
  const r = categorize(
    { title: "hello", description: "just testing", reporterRole: "teacher", moduleKey: null, screenRoute: null, platform: "android", appVersion: "1.0" },
    NO_DIAG,
  );
  assertEquals(r.category, "unknown");
});

Deno.test("suggestSeverity: crash + 5xx => sev1", () => {
  assertEquals(suggestSeverity("crash", diag(["recent 5xx (server error)"]), "app crashed"), "sev1");
});

Deno.test("suggestSeverity: login_auth 'everyone' => sev1", () => {
  assertEquals(suggestSeverity("login_auth", NO_DIAG, "nobody can log in, everyone is blocked"), "sev1");
});

Deno.test("suggestSeverity: permission_rbac => sev2", () => {
  assertEquals(suggestSeverity("permission_rbac", NO_DIAG, "access denied"), "sev2");
});

Deno.test("suggestSeverity: cosmetic ui => sev4", () => {
  assertEquals(suggestSeverity("ui_display", NO_DIAG, "the font color is wrong"), "sev4");
});

Deno.test("suggestSeverity: default => sev3", () => {
  assertEquals(suggestSeverity("data_incorrect", NO_DIAG, "value looks off"), "sev3");
});

Deno.test("assembleDeterministic produces a complete package with a 403 root cause", () => {
  const pkg = assembleDeterministic(
    { title: "Cannot open marks", description: "access denied", reporterRole: "teacher", moduleKey: "sis", screenRoute: "/sis/marks", platform: "android", appVersion: "1.2.0" },
    diag(["recent 403 (permission/RBAC)"], { apiErrorCount: 1, topErrorStatus: 403, topErrorPath: "/sis/marks", failingCorrelationId: "ak-1" }),
  );
  assertEquals(pkg.categorization.category, "permission_rbac");
  assertEquals(pkg.severitySuggestion, "sev2");
  assertEquals(pkg.likelyRootCause.includes("403"), true);
  assertEquals(pkg.suggestedNextSteps.length > 0, true);
  // confidence: 40 base +15 category +15 apiError +10 module +10 correlation = 90 -> capped 85
  assertEquals(pkg.confidence, 85);
});

Deno.test("safeParseEnrichment parses fenced JSON and validates fields", () => {
  const out = safeParseEnrichment(
    'Here you go:\n```json\n{"summary":"a","likelyRootCause":"b","suggestedNextSteps":["x","y"],"severity":"sev2","confidence":72}\n```',
  );
  assertEquals(out?.summary, "a");
  assertEquals(out?.severity, "sev2");
  assertEquals(out?.confidence, 72);
  assertEquals(out?.suggestedNextSteps?.length, 2);
});

Deno.test("safeParseEnrichment rejects non-JSON", () => {
  assertEquals(safeParseEnrichment("no json here"), null);
});

Deno.test("safeParseEnrichment drops an invalid severity", () => {
  const out = safeParseEnrichment('{"summary":"a","severity":"sevX"}');
  assertEquals(out?.summary, "a");
  assertEquals(out?.severity, undefined);
});
