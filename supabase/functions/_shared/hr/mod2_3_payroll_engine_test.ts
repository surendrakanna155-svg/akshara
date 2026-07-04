// P1-CODE-5 · MOD-2 (payroll engine) + MOD-3 (employee-code uniqueness).
// Pure money-safety tests for the salary-structure → run generation engine.
import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  employeeCodeExists,
  generatePayrollRun,
  parseSalaryStructure,
  upsertSalaryStructure,
  validatePayrollEntries,
  type SalaryStructure,
} from "./hr_write_handlers.ts";

function structure(over: Partial<SalaryStructure> = {}): Record<string, unknown> {
  return {
    employeeId: "e1",
    employeeCode: "EMP-1",
    employeeName: "Asha",
    department: "academics",
    basicPay: 40000,
    allowances: 8000,
    deductions: 3000,
    ...over,
  };
}

// ── MOD-2 · parseSalaryStructure ─────────────────────────────────────────────
Deno.test("MOD-2: parseSalaryStructure accepts a valid structure", () => {
  const s = parseSalaryStructure(structure());
  assertEquals(s.employeeId, "e1");
  assertEquals(s.basicPay, 40000);
  assertEquals(s.allowances, 8000);
  assertEquals(s.deductions, 3000);
});

Deno.test("MOD-2: parseSalaryStructure rejects negative components (422)", () => {
  assertThrows(() => parseSalaryStructure(structure({ allowances: -1 })));
  assertThrows(() => parseSalaryStructure(structure({ deductions: -100 })));
});

Deno.test("MOD-2: parseSalaryStructure rejects basicPay <= 0", () => {
  assertThrows(() => parseSalaryStructure(structure({ basicPay: 0 })));
});

Deno.test("MOD-2: parseSalaryStructure rejects deductions exceeding basic+allowances (negative net)", () => {
  assertThrows(() =>
    parseSalaryStructure(structure({ basicPay: 10000, allowances: 0, deductions: 15000 }))
  );
});

// ── MOD-2 · upsertSalaryStructure ────────────────────────────────────────────
Deno.test("MOD-2: upsertSalaryStructure inserts then updates by employeeId", () => {
  const s1 = parseSalaryStructure(structure());
  const afterInsert = upsertSalaryStructure({}, s1);
  assertEquals((afterInsert.structures as unknown[]).length, 1);

  const s2 = parseSalaryStructure(structure({ basicPay: 50000 }));
  const afterUpdate = upsertSalaryStructure(afterInsert, s2);
  const structures = afterUpdate.structures as Array<Record<string, unknown>>;
  assertEquals(structures.length, 1, "same employeeId updates in place, not appends");
  assertEquals(structures[0]!.basicPay, 50000);
});

// ── MOD-2 · generatePayrollRun ───────────────────────────────────────────────
function snapshotWith(structures: Array<Record<string, unknown>>): Record<string, unknown> {
  return { structures };
}

Deno.test("MOD-2: generatePayrollRun computes netPay = basic + allowances − deductions", () => {
  const snap = snapshotWith([structure(), structure({ employeeId: "e2", employeeCode: "EMP-2", basicPay: 30000, allowances: 2000, deductions: 1000 })]);
  const { run, entries, next } = generatePayrollRun(snap, { runId: "run-jul", period: "2026-07" });

  assertEquals(entries.length, 2);
  assertEquals(entries[0]!.netPay, 40000 + 8000 - 3000); // 45000
  assertEquals(entries[1]!.netPay, 30000 + 2000 - 1000); // 31000
  assertEquals(entries[0]!.runId, "run-jul");
  assertEquals(run.status, "draft");
  assertEquals(run.employeeCount, 2);
  // Entries land in the snapshot tagged with the run.
  assertEquals((next.entries as unknown[]).length, 2);
  // And the generated lines satisfy the processor's money-safety guards.
  validatePayrollEntries(entries as Array<Record<string, unknown>>);
});

Deno.test("MOD-2: generatePayrollRun with no structures throws PAYROLL_NO_STRUCTURES (422)", () => {
  assertThrows(() => generatePayrollRun(snapshotWith([]), { runId: "r", period: "2026-07" }));
});

Deno.test("MOD-2: generatePayrollRun filters to the requested employeeIds", () => {
  const snap = snapshotWith([
    structure({ employeeId: "e1" }),
    structure({ employeeId: "e2", employeeCode: "EMP-2" }),
    structure({ employeeId: "e3", employeeCode: "EMP-3" }),
  ]);
  const { entries } = generatePayrollRun(snap, {
    runId: "r",
    period: "2026-07",
    employeeIds: ["e1", "e3"],
  });
  assertEquals(entries.map((e) => e.employeeId).sort(), ["e1", "e3"]);
});

Deno.test("MOD-2: regenerating a DRAFT run replaces its entries (idempotent), keeps other runs", () => {
  const snap = snapshotWith([structure(), structure({ employeeId: "e2", employeeCode: "EMP-2" })]);
  // A pre-existing OTHER run's entry must be preserved.
  snap.runs = [{ id: "run-other", status: "draft" }];
  snap.entries = [{ runId: "run-other", employeeId: "x", basicPay: 1, allowances: 0, deductions: 0, netPay: 1 }];

  const first = generatePayrollRun(snap, { runId: "run-jul", period: "2026-07" });
  const second = generatePayrollRun(first.next, { runId: "run-jul", period: "2026-07", employeeIds: ["e1"] });

  const entries = second.next.entries as Array<Record<string, unknown>>;
  const julEntries = entries.filter((e) => e.runId === "run-jul");
  const otherEntries = entries.filter((e) => e.runId === "run-other");
  assertEquals(julEntries.length, 1, "regenerate replaced 2 lines with the filtered 1");
  assertEquals(otherEntries.length, 1, "other run's entries preserved");
});

Deno.test("MOD-2: regenerating an ALREADY-PROCESSED run is refused (409)", () => {
  const snap = snapshotWith([structure()]);
  snap.runs = [{ id: "run-jul", status: "processed" }];
  assertThrows(() => generatePayrollRun(snap, { runId: "run-jul", period: "2026-07" }));
});

// ── MOD-3 · employee-code uniqueness ─────────────────────────────────────────
Deno.test("MOD-3: employeeCodeExists detects a case-insensitive collision", () => {
  const existing = [{ employeeCode: "EMP-1" }, { employee_code: "EMP-2" }];
  assertEquals(employeeCodeExists(existing, "emp-1"), true);
  assertEquals(employeeCodeExists(existing, " EMP-2 "), true);
  assertEquals(employeeCodeExists(existing, "EMP-3"), false);
});
