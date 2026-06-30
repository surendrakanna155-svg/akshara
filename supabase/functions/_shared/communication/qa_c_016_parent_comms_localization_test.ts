// QW7 · QA-C-016 — Parent Communication Localization (DETERMINISTIC catalog).
//
// Owner architecture (2026-06-30): parent-facing comms are localized ONLY via
// predefined multilingual template catalogs with placeholders — NO LLM. These
// tests certify: a non-English parent gets the catalog variant with placeholders
// substituted; unknown language/code falls back to English deterministically;
// and the send-path keeps the existing English DB template for English / staff /
// non-catalogued recipients (no regression). All DB-free via the app.ts-style seam.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  hasLocalizedTemplate,
  localizeNotification,
  normalizeParentLanguage,
  parentLanguageCodeFromName,
} from "./parent_comms_localization.ts";
import { enqueueFromTemplate } from "./notification_service.ts";
import type { AccessTokenClaims } from "../jwt.ts";

// ── the deterministic engine ────────────────────────────────────────────────
Deno.test("QA-C-016: localizes a parent template into the parent's language + substitutes placeholders", () => {
  const r = localizeNotification("attendance_absence", "te", {
    studentName: "Asha",
    date: "30 Jun",
  })!;
  assertEquals(r.languageUsed, "te");
  assertEquals(r.body.includes("Asha"), true, "placeholder substituted");
  assertEquals(r.body.includes("30 Jun"), true);
  assertEquals(r.body.includes("{{"), false, "no unresolved placeholders");
  assertEquals(r.body.includes("was marked absent"), false, "not the English text");
  assertEquals(r.subject, "హాజరు హెచ్చరిక");
});

Deno.test("QA-C-016: unknown language falls back to English deterministically", () => {
  const r = localizeNotification("fee_reminder", "fr", {
    studentName: "Asha",
    amount: "4200",
    dueDate: "15 Jul",
  })!;
  assertEquals(r.languageUsed, "en");
  assertEquals(r.body.includes("Asha"), true);
  assertEquals(r.body.includes("4200"), true);
  assertEquals(r.subject, "Fee Reminder");
});

Deno.test("QA-C-016: a non-catalogued code returns null (caller keeps the English DB template)", () => {
  assertEquals(localizeNotification("staff_payroll_processed", "te", {}), null);
  assertEquals(hasLocalizedTemplate("staff_payroll_processed"), false);
  assertEquals(hasLocalizedTemplate("attendance_absence"), true);
});

Deno.test("QA-C-016: normalizeParentLanguage defaults unknown/empty to English", () => {
  assertEquals(normalizeParentLanguage(null), "en");
  assertEquals(normalizeParentLanguage(""), "en");
  assertEquals(normalizeParentLanguage("xx"), "en");
  assertEquals(normalizeParentLanguage("UR"), "ur");
});

Deno.test("QA-C-016: parentLanguageCodeFromName bridges stored names → catalog codes", () => {
  // The preference store keeps NAMES; the catalog keys on CODES.
  assertEquals(parentLanguageCodeFromName("telugu"), "te");
  assertEquals(parentLanguageCodeFromName("Urdu"), "ur");
  assertEquals(parentLanguageCodeFromName("english"), "en");
  assertEquals(parentLanguageCodeFromName("te"), "te"); // also accepts a code
  assertEquals(parentLanguageCodeFromName("klingon"), "en"); // unsupported → English
  assertEquals(parentLanguageCodeFromName(null), "en");
});

Deno.test("QA-C-016: every catalogued code defines an English fallback variant", () => {
  const vars = {
    studentName: "x",
    date: "x",
    amount: "x",
    dueDate: "x",
    examName: "x",
  };
  for (const code of ["attendance_absence", "fee_reminder", "exam_results_published"]) {
    const r = localizeNotification(code, "en", vars);
    assertEquals(r !== null, true, `${code} has an English variant`);
    assertEquals(r!.languageUsed, "en");
    assertEquals(r!.body.includes("{{"), false);
  }
});

Deno.test("QA-C-016: all 6 non-English languages produce a non-English, placeholder-free body", () => {
  for (const lang of ["te", "hi", "ta", "kn", "ml", "ur"]) {
    const r = localizeNotification("attendance_absence", lang, {
      studentName: "Asha",
      date: "30 Jun",
    })!;
    assertEquals(r.languageUsed, lang);
    assertEquals(r.body.includes("Asha"), true);
    assertEquals(r.body.includes("{{"), false);
    assertEquals(r.body.includes("was marked absent"), false);
  }
});

// ── the send-path seam (DB-free) ────────────────────────────────────────────
function claims(): AccessTokenClaims {
  return { sub: "u1", tenant_id: "org1", school_id: "sch1" } as AccessTokenClaims;
}

/** Fake query client: serves the English DB template on SELECT, captures the INSERT. */
class FakeDb {
  capturedBody: string | undefined;
  capturedSubject: string | null | undefined;
  // deno-lint-ignore no-explicit-any
  async queryObject<T = any>(sql: string, params?: unknown[]): Promise<T[]> {
    if (sql.includes("FROM notification_templates")) {
      return [{
        id: "tmpl1",
        channel: "push",
        subject_template: "Attendance Alert",
        body_template: "Dear Parent, {{studentName}} was marked absent on {{date}}.",
        variables: [],
      }] as unknown as T[];
    }
    if (sql.includes("INSERT INTO notification_deliveries")) {
      this.capturedSubject = (params?.[6] ?? null) as string | null;
      this.capturedBody = params?.[7] as string;
      return [{ id: "d1", rendered_body: params?.[7], rendered_subject: params?.[6] }] as unknown as T[];
    }
    return [] as T[];
  }
}

Deno.test("QA-C-016 (send-path): a Telugu parent gets the localized body enqueued", async () => {
  const db = new FakeDb();
  // deno-lint-ignore no-explicit-any
  await enqueueFromTemplate(db as any, claims(), {
    templateCode: "attendance_absence",
    variables: { studentName: "Asha", date: "30 Jun" },
    recipientUserId: "parent1",
    recipientLanguage: "te",
  });
  assertEquals(db.capturedBody!.includes("Asha"), true);
  assertEquals(db.capturedBody!.includes("{{"), false);
  assertEquals(db.capturedBody!.includes("was marked absent"), false, "localized, not English");
  assertEquals(db.capturedSubject, "హాజరు హెచ్చరిక");
});

Deno.test("QA-C-016 (send-path): no language keeps the English DB template (no regression)", async () => {
  const db = new FakeDb();
  // deno-lint-ignore no-explicit-any
  await enqueueFromTemplate(db as any, claims(), {
    templateCode: "attendance_absence",
    variables: { studentName: "Asha", date: "30 Jun" },
    recipientUserId: "parent1",
  });
  assertEquals(db.capturedBody, "Dear Parent, Asha was marked absent on 30 Jun.");
});

Deno.test("QA-C-016 (send-path): a Telugu parent on a NON-catalogued template falls back to the English DB template", async () => {
  const db = new FakeDb();
  // deno-lint-ignore no-explicit-any
  await enqueueFromTemplate(db as any, claims(), {
    templateCode: "staff_generic_announcement", // not in the parent catalog
    variables: { studentName: "Asha", date: "30 Jun" },
    recipientUserId: "parent1",
    recipientLanguage: "te",
  });
  assertEquals(db.capturedBody, "Dear Parent, Asha was marked absent on 30 Jun.");
});
