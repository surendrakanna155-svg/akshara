import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { extractTemplateVariables, renderTemplate } from "./template_renderer.ts";

Deno.test("renderTemplate substitutes variables", () => {
  const rendered = renderTemplate(
    "Hello {{name}}, fee ₹{{amount}} due {{due_date}}.",
    { name: "Ravi", amount: "4200", due_date: "15 Jun" },
  );
  assertEquals(rendered, "Hello Ravi, fee ₹4200 due 15 Jun.");
});

Deno.test("extractTemplateVariables finds keys", () => {
  const keys = extractTemplateVariables("{{term}} — {{amount}}");
  assertEquals(keys.sort(), ["amount", "term"]);
});

