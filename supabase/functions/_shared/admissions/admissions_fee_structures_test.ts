import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { feeStructureToAdmissionsOption } from "./admissions_extras_handlers.ts";
import type {
  FinanceFeeStructureItemRow,
  FinanceFeeStructureRow,
} from "../finance/finance_mapper.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const STAFF = "a3000000-0000-4000-8000-000000000009";

function structure(overrides: Partial<FinanceFeeStructureRow> = {}): FinanceFeeStructureRow {
  return {
    id: "struct-1",
    organization_id: ORG,
    school_id: SCHOOL,
    name: "Standard CBSE",
    academic_year: "2026-27",
    academic_year_id: null,
    // Cap 67 — real class/section binding on finance_fee_structures; null =
    // unbound (this admissions-side fixture doesn't exercise binding).
    class_id: null,
    section_id: null,
    description: "Classes 1-5",
    status: "active",
    created_by: STAFF,
    created_at: "2026-06-12T00:00:00.000Z",
    updated_at: "2026-06-12T00:00:00.000Z",
    ...overrides,
  };
}

function item(overrides: Partial<FinanceFeeStructureItemRow> = {}): FinanceFeeStructureItemRow {
  return {
    id: "item-1",
    fee_structure_id: "struct-1",
    organization_id: ORG,
    school_id: SCHOOL,
    fee_head: "tuition:Annual Tuition",
    amount: "50000",
    sort_order: 0,
    created_at: "2026-06-12T00:00:00.000Z",
    ...overrides,
  };
}

// #4: GET /admissions/fee-structures reuses Finance's own repository + mapper
// (feeStructureToApi) and reshapes the result into the admissions client's
// FeeStructureOption contract. This proves that reshape yields real rows —
// not an empty/fabricated list — from genuine Finance fee-structure data.
Deno.test("feeStructureToAdmissionsOption: reshapes a real Finance structure into the admissions picker contract", () => {
  const option = feeStructureToAdmissionsOption(structure(), [
    item({ id: "item-1", fee_head: "tuition:Annual Tuition", amount: "150000", sort_order: 0 }),
    item({ id: "item-2", fee_head: "activity:Lab Fee", amount: "35000", sort_order: 1 }),
  ]);

  assertEquals(option.id, "struct-1");
  assertEquals(option.label, "Standard CBSE");
  // Sum of item amounts, formatted like Finance's own totalAnnual.
  assertEquals(option.annualAmount, "185000");
  // Finance doesn't yet track distinct installment plans (installmentOptions
  // is always []) — default to 1 rather than fabricate a count.
  assertEquals(option.installments, 1);
});

Deno.test("feeStructureToAdmissionsOption: multiple structures each map to a distinct option (list has rows)", () => {
  const options = [
    feeStructureToAdmissionsOption(structure({ id: "struct-1", name: "Standard CBSE" }), [
      item({ fee_structure_id: "struct-1", amount: "150000" }),
    ]),
    feeStructureToAdmissionsOption(structure({ id: "struct-2", name: "Premium + Transport" }), [
      item({ fee_structure_id: "struct-2", amount: "215000" }),
    ]),
  ];

  assertEquals(options.length, 2);
  assertEquals(options.map((o) => o.id), ["struct-1", "struct-2"]);
  assertEquals(options.map((o) => o.label), ["Standard CBSE", "Premium + Transport"]);
});
