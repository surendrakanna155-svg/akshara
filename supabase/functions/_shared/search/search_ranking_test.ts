// Adaptive AI — P3-AI-2 / W2.S: search ranking tests (pure, DB-free).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type AdmissionCandidate,
  type BroadcastCandidate,
  classifyAdmissionMatch,
  classifyBroadcastMatch,
  classifyClassMatch,
  classifyFinanceInvoiceMatch,
  classifyStaffMatch,
  classifyStudentMatch,
  type ClassCandidate,
  type FinanceInvoiceCandidate,
  orderResults,
  type StaffCandidate,
  type StudentCandidate,
  studentSubtitle,
  toAdmissionResult,
  toBroadcastResult,
  toClassResult,
  toFinanceInvoiceResult,
  toStaffResult,
  toStudentResult,
} from "./search_ranking.ts";

function cand(over: Partial<StudentCandidate> = {}): StudentCandidate {
  return {
    id: "s1",
    displayName: "Ramesh Kumar",
    studentCode: "STU-0001",
    admissionNumber: "2024-101",
    publicStudentId: "DPS-0001",
    className: "6",
    sectionName: "B",
    rollNumber: "12",
    status: "active",
    ...over,
  };
}

Deno.test("classifyStudentMatch follows the priority ladder", () => {
  // admission# beats everything
  assertEquals(classifyStudentMatch(cand(), "2024"), "admission_number");
  // entity id (student_code / public id) when admission# doesn't match
  assertEquals(classifyStudentMatch(cand({ admissionNumber: null }), "stu-0001"), "entity_id");
  assertEquals(classifyStudentMatch(cand({ admissionNumber: null, studentCode: "X" }), "dps-0001"), "entity_id");
  // roll exact
  assertEquals(
    classifyStudentMatch(cand({ admissionNumber: null, studentCode: "X", publicStudentId: null }), "12"),
    "roll_class",
  );
  // name prefix
  assertEquals(
    classifyStudentMatch(cand({ admissionNumber: null, studentCode: "X", publicStudentId: null, rollNumber: null }), "ramesh"),
    "name_prefix",
  );
  // name partial (contains, not prefix)
  assertEquals(
    classifyStudentMatch(cand({ admissionNumber: null, studentCode: "X", publicStudentId: null, rollNumber: null }), "kumar"),
    "name_partial",
  );
});

Deno.test("studentSubtitle carries disambiguating identifiers (decision 6)", () => {
  assertEquals(studentSubtitle(cand()), "Class 6-B · Roll 12 · Adm# 2024-101 · ID DPS-0001");
  // Non-active status is surfaced; missing fields are omitted.
  assertEquals(
    studentSubtitle(cand({ sectionName: null, rollNumber: null, publicStudentId: null, status: "alumni" })),
    "Class 6 · Adm# 2024-101 · alumni",
  );
});

Deno.test("toStudentResult builds a navigable result with a deep link", () => {
  const r = toStudentResult(cand(), "ramesh");
  assertEquals(r.category, "students");
  assertEquals(r.deepLink, "/students/s1");
  assertEquals(r.title, "Ramesh Kumar");
  assertEquals(r.matchField, "name_prefix");
  assertEquals(r.rank, 4);
});

Deno.test("orderResults ranks by the ladder, then name, then id (deterministic)", () => {
  const partial = toStudentResult(cand({ id: "p", displayName: "Zeb Kumar", admissionNumber: null, studentCode: "X", publicStudentId: null, rollNumber: null }), "kumar");
  const admission = toStudentResult(cand({ id: "a", displayName: "Aay Kumar" }), "2024");
  const ordered = orderResults([partial, admission]);
  assertEquals(ordered.map((r) => r.id), ["a", "p"]); // admission# (rank 0) first
});

Deno.test("names are not assumed unique — same name, distinct rows both kept", () => {
  const a = toStudentResult(cand({ id: "s1", rollNumber: "10", admissionNumber: null, studentCode: "X", publicStudentId: null }), "ramesh");
  const b = toStudentResult(cand({ id: "s2", rollNumber: "22", admissionNumber: null, studentCode: "Y", publicStudentId: null }), "ramesh");
  const ordered = orderResults([a, b]);
  assertEquals(ordered.length, 2);
  assertEquals(ordered.map((r) => r.id), ["s1", "s2"]); // tie-break by id, both retained
});

// ─── Staff ───────────────────────────────────────────────────────────────────

function staff(over: Partial<StaffCandidate> = {}): StaffCandidate {
  return { id: "e1", displayName: "Priya Sharma", employeeCode: "EMP-101", email: "priya@akshara.edu", phone: "+91 98765 43210", status: "active", ...over };
}

Deno.test("staff match ladder: code → contact → name", () => {
  assertEquals(classifyStaffMatch(staff(), "emp-1"), "entity_id");
  assertEquals(classifyStaffMatch(staff({ employeeCode: "X" }), "9876543210"), "phone");
  assertEquals(classifyStaffMatch(staff({ employeeCode: "X", phone: null, email: null }), "priya"), "name_prefix");
  assertEquals(classifyStaffMatch(staff({ employeeCode: "X", phone: null, email: null }), "sharma"), "name_partial");
});

Deno.test("toStaffResult navigates to the staff screen", () => {
  const r = toStaffResult(staff(), "priya");
  assertEquals(r.category, "staff");
  assertEquals(r.deepLink, "/staff/e1");
  assertEquals(r.subtitle, "EMP-101");
});

// ─── Admissions ──────────────────────────────────────────────────────────────

function lead(over: Partial<AdmissionCandidate> = {}): AdmissionCandidate {
  return { id: "l1", studentName: "Arjun Rao", parentName: "Sita Rao", classLabel: "1", phone: "+91 90000 11111", stage: "site_visit", ...over };
}

Deno.test("admission match: phone → student/parent name prefix → partial", () => {
  assertEquals(classifyAdmissionMatch(lead(), "9000011111"), "phone");
  assertEquals(classifyAdmissionMatch(lead({ phone: null }), "arjun"), "name_prefix");
  assertEquals(classifyAdmissionMatch(lead({ phone: null }), "sita"), "name_prefix"); // parent prefix
  assertEquals(classifyAdmissionMatch(lead({ phone: null }), "rao"), "name_partial");
});

Deno.test("toAdmissionResult carries class/parent/stage and a lead deep link", () => {
  const r = toAdmissionResult(lead(), "arjun");
  assertEquals(r.category, "admissions");
  assertEquals(r.deepLink, "/admissions/leads/l1");
  assertEquals(r.subtitle, "Class 1 · Parent: Sita Rao · site visit");
});

// ─── Finance (invoices) ──────────────────────────────────────────────────────

function invoice(over: Partial<FinanceInvoiceCandidate> = {}): FinanceInvoiceCandidate {
  return {
    id: "inv1",
    invoiceNumber: "INV-2026-0042",
    invoiceStatus: "issued",
    dueDate: "2026-08-01",
    studentName: "Ramesh Kumar",
    ...over,
  };
}

Deno.test("finance match ladder: invoice number prefix → student name prefix → partial", () => {
  assertEquals(classifyFinanceInvoiceMatch(invoice(), "inv-2026"), "entity_id");
  assertEquals(classifyFinanceInvoiceMatch(invoice(), "ramesh"), "name_prefix");
  assertEquals(classifyFinanceInvoiceMatch(invoice(), "kumar"), "name_partial");
});

Deno.test("exact invoice number beats a student-name partial match", () => {
  const byNumber = toFinanceInvoiceResult(invoice(), "inv-2026");
  const byNamePartial = toFinanceInvoiceResult(invoice({ id: "inv2", invoiceNumber: "INV-2026-0099" }), "kumar");
  const ordered = orderResults([byNamePartial, byNumber]);
  assertEquals(ordered.map((r) => r.id), ["inv1", "inv2"]); // entity_id (1) before name_partial (5)
});

Deno.test("toFinanceInvoiceResult navigates to the invoice screen", () => {
  const r = toFinanceInvoiceResult(invoice(), "inv-2026");
  assertEquals(r.category, "finance");
  assertEquals(r.title, "INV-2026-0042");
  assertEquals(r.deepLink, "/finance/invoices/inv1");
  assertEquals(r.subtitle, "Ramesh Kumar · issued · Due 2026-08-01");
});

// ─── Communications (broadcasts) ────────────────────────────────────────────

function broadcast(over: Partial<BroadcastCandidate> = {}): BroadcastCandidate {
  return { id: "b1", title: "Annual Day Celebration", audience: "all_parents", status: "sent", ...over };
}

Deno.test("broadcast match ladder: title prefix → title partial", () => {
  assertEquals(classifyBroadcastMatch(broadcast(), "annual"), "name_prefix");
  assertEquals(classifyBroadcastMatch(broadcast(), "celebration"), "name_partial");
});

Deno.test("broadcast prefix beats partial", () => {
  const prefix = toBroadcastResult(broadcast(), "annual");
  const partial = toBroadcastResult(broadcast({ id: "b2", title: "Sports Day Celebration" }), "celebration");
  const ordered = orderResults([partial, prefix]);
  assertEquals(ordered.map((r) => r.id), ["b1", "b2"]); // name_prefix (4) before name_partial (5)
});

Deno.test("toBroadcastResult navigates to the broadcast screen", () => {
  const r = toBroadcastResult(broadcast(), "annual");
  assertEquals(r.category, "communications");
  assertEquals(r.deepLink, "/communications/broadcasts/b1");
  assertEquals(r.subtitle, "all parents · sent");
});

// ─── Classes ─────────────────────────────────────────────────────────────────

function klass(over: Partial<ClassCandidate> = {}): ClassCandidate {
  return { label: "8-A", className: "8", sectionName: "A", enrollmentCount: 32, ...over };
}

Deno.test("class match ladder: exact label → class-name prefix → partial", () => {
  assertEquals(classifyClassMatch(klass(), "8-a"), "roll_class");
  assertEquals(classifyClassMatch(klass({ label: "8-B", sectionName: "B" }), "8"), "name_prefix");
  assertEquals(classifyClassMatch(klass({ label: "10-A", className: "10", sectionName: "A" }), "0-a"), "name_partial");
});

Deno.test("class exact label beats a class-name prefix match", () => {
  const exact = toClassResult(klass(), "8-a");
  const prefix = toClassResult(klass({ label: "8-B", sectionName: "B" }), "8");
  const ordered = orderResults([prefix, exact]);
  assertEquals(ordered.map((r) => r.id), ["8-A", "8-B"]); // roll_class (3) before name_prefix (4)
});

Deno.test("toClassResult uses the composed label as id/title and navigates by label", () => {
  const r = toClassResult(klass(), "8-a");
  assertEquals(r.category, "classes");
  assertEquals(r.id, "8-A");
  assertEquals(r.title, "8-A");
  assertEquals(r.deepLink, "/academics/classes/8-A");
  assertEquals(r.subtitle, "Class · 32 enrolled");
});

Deno.test("toClassResult composes a bare label when there is no section", () => {
  const r = toClassResult(klass({ label: "Nursery", className: "Nursery", sectionName: null }), "nurs");
  assertEquals(r.title, "Nursery");
  assertEquals(r.deepLink, "/academics/classes/Nursery");
});
