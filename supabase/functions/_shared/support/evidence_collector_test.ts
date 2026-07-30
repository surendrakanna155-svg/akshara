import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildApiCallsEvidence,
  buildBreadcrumbsEvidence,
  buildClientContextEvidence,
  buildDiagnostics,
  deriveIncidentContext,
  redactFreeText,
} from "./evidence_collector.ts";

Deno.test("redactFreeText masks emails and long digit runs, caps length", () => {
  const r = redactFreeText("contact ravi@school.com or 9876543210 for help");
  assertEquals(r.redacted, true);
  assertEquals(r.value.includes("[email]"), true);
  assertEquals(r.value.includes("[number]"), true);
  assertEquals(r.value.includes("ravi@school.com"), false);
  assertEquals(r.value.includes("9876543210"), false);
});

Deno.test("redactFreeText leaves clean technical text intact", () => {
  const r = redactFreeText("tapped Save on 500 error");
  assertEquals(r.redacted, false);
  assertEquals(r.value, "tapped Save on 500 error");
});

Deno.test("deriveIncidentContext lifts the first correlation id and trims fields", () => {
  const d = deriveIncidentContext({
    appVersion: " 1.2.3 ",
    platform: "android",
    correlationIds: ["", "ak-123-abc", "ak-456"],
    moduleKey: "finance",
  });
  assertEquals(d.appVersion, "1.2.3");
  assertEquals(d.platform, "android");
  assertEquals(d.correlationId, "ak-123-abc");
  assertEquals(d.moduleKey, "finance");
  assertEquals(d.deviceModel, null);
});

Deno.test("buildBreadcrumbsEvidence redacts free-text messages", () => {
  const ev = buildBreadcrumbsEvidence({
    breadcrumbs: [
      { type: "navigation", route: "/finance", at: "2026-07-20T10:00:00Z" },
      { type: "error", message: "failed for parent@x.com", at: "2026-07-20T10:01:00Z" },
    ],
  });
  assertEquals(ev.redacted, true);
  const items = ev.value.items as Array<Record<string, unknown>>;
  assertEquals(items.length, 2);
  assertEquals(String(items[1].message).includes("[email]"), true);
});

Deno.test("buildApiCallsEvidence counts errors", () => {
  const ev = buildApiCallsEvidence({
    recentApiCalls: [
      { method: "GET", path: "/finance/x", statusCode: 200 },
      { method: "POST", path: "/finance/y", statusCode: 403 },
      { method: "GET", path: "/finance/z", statusCode: 500 },
    ],
  });
  assertEquals(ev.value.count, 3);
  assertEquals(ev.value.errorCount, 2);
});

Deno.test("buildClientContextEvidence is not redacted (technical only)", () => {
  const ev = buildClientContextEvidence({ appVersion: "1.0.0", platform: "ios" });
  assertEquals(ev.redacted, false);
  assertEquals(ev.value.appVersion, "1.0.0");
});

Deno.test("buildDiagnostics surfaces 401/403/5xx signals and failing correlation", () => {
  const d = buildDiagnostics({
    appVersion: null,
    platform: "web",
    moduleKey: "sis",
    screenRoute: "/sis",
    correlationId: "ak-fail-1",
    apiCalls: [
      { statusCode: 403, path: "/sis/students", correlationId: "ak-403" },
      { statusCode: 500, path: "/sis/marks", correlationId: "ak-500" },
    ],
    auditCount: 3,
    breadcrumbCount: 5,
  });
  assertEquals(d.apiErrorCount, 2);
  assertEquals(d.failingCorrelationId, "ak-fail-1");
  assertEquals(d.hasAppVersion, false);
  assertEquals(d.signals.some((s) => s.includes("403")), true);
  assertEquals(d.signals.some((s) => s.includes("5xx")), true);
  assertEquals(d.signals.some((s) => s.includes("app version not reported")), true);
});
