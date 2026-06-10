export function renderTemplate(
  template: string,
  variables: Record<string, string>,
): string {
  return template.replace(/\{\{(\w+)\}\}/g, (_match, key: string) => {
    return variables[key] ?? `{{${key}}}`;
  });
}

export function extractTemplateVariables(template: string): string[] {
  const keys = new Set<string>();
  for (const match of template.matchAll(/\{\{(\w+)\}\}/g)) {
    keys.add(match[1]!);
  }
  return [...keys];
}
