import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  collectionStatusToApi,
  installmentStatusFromInvoice,
} from "./finance_status_codec.ts";

Deno.test("collectionStatusToApi maps backend to client statuses", () => {
  assertEquals(collectionStatusToApi("draft"), "pending");
  assertEquals(collectionStatusToApi("completed"), "completed");
  assertEquals(collectionStatusToApi("cancelled"), "failed");
});

Deno.test("installmentStatusFromInvoice maps invoice lifecycle", () => {
  assertEquals(installmentStatusFromInvoice("issued"), "pending");
  assertEquals(installmentStatusFromInvoice("partially_paid"), "pending");
  assertEquals(installmentStatusFromInvoice("paid"), "completed");
  assertEquals(installmentStatusFromInvoice("cancelled"), "failed");
});
