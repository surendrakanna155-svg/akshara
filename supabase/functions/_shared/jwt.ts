import { SignJWT, jwtVerify } from "npm:jose";

export type AuthScope =
  | "school"
  | "organization"
  | "school_group"
  | "parent"
  | "student"
  | "platform";

export interface AccessTokenClaims {
  sub: string;
  tenant_id: string;
  organization_id: string;
  school_id: string | null;
  /** Primary role slug (backward-compatible with v6.0 `role` claim). */
  role: string;
  role_slugs: string[];
  primary_role: string;
  permissions: string[];
  permissions_version: number;
  scope: AuthScope;
  school_group_id: string | null;
  student_id: string | null;
  child_ids: string[];
  /** G4 — true when the org runs more than one school (chain/trust). Optional so
   * existing claim literals stay valid; absent resolves to false. */
  is_chain_organization?: boolean;
  session_id: string;
}

export async function signAccessToken(
  secret: string,
  claims: AccessTokenClaims,
  ttlSeconds: number,
): Promise<string> {
  const key = new TextEncoder().encode(secret);
  return await new SignJWT({
    tenant_id: claims.tenant_id,
    organization_id: claims.organization_id,
    school_id: claims.school_id,
    role: claims.role,
    role_slugs: claims.role_slugs,
    primary_role: claims.primary_role,
    permissions: claims.permissions,
    permissions_version: claims.permissions_version,
    scope: claims.scope,
    school_group_id: claims.school_group_id,
    student_id: claims.student_id,
    child_ids: claims.child_ids,
    is_chain_organization: claims.is_chain_organization ?? false,
    session_id: claims.session_id,
  })
    .setProtectedHeader({ alg: "HS256", typ: "JWT" })
    .setSubject(claims.sub)
    .setIssuedAt()
    .setExpirationTime(Math.floor(Date.now() / 1000) + ttlSeconds)
    .sign(key);
}

export async function verifyAccessToken(
  secret: string,
  token: string,
): Promise<AccessTokenClaims | null> {
  try {
    const key = new TextEncoder().encode(secret);
    const { payload } = await jwtVerify(token, key, { algorithms: ["HS256"] });
    const primaryRole = (payload.primary_role as string | undefined) ??
      (payload.role as string);
    const roleSlugs = (payload.role_slugs as string[] | undefined) ??
      (primaryRole ? [primaryRole] : []);
    const childIds = (payload.child_ids as string[] | undefined) ?? [];
    return {
      sub: payload.sub as string,
      tenant_id: payload.tenant_id as string,
      organization_id: payload.organization_id as string,
      school_id: (payload.school_id as string | null) ?? null,
      role: primaryRole,
      role_slugs: roleSlugs,
      primary_role: primaryRole,
      permissions: (payload.permissions as string[]) ?? [],
      permissions_version: (payload.permissions_version as number) ?? 1,
      scope: (payload.scope as AuthScope) ?? "school",
      school_group_id: (payload.school_group_id as string | null) ?? null,
      student_id: (payload.student_id as string | null) ?? null,
      child_ids: childIds,
      is_chain_organization: (payload.is_chain_organization as boolean | undefined) ?? false,
      session_id: payload.session_id as string,
    };
  } catch {
    return null;
  }
}

export function bearerToken(req: Request): string | null {
  const header = req.headers.get("Authorization");
  if (!header?.startsWith("Bearer ")) return null;
  return header.slice("Bearer ".length).trim();
}

export async function hashToken(value: string): Promise<string> {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function randomToken(): string {
  return crypto.randomUUID().replace(/-/g, "") +
    crypto.randomUUID().replace(/-/g, "");
}

export function expiresAtIso(seconds: number): string {
  return new Date(Date.now() + seconds * 1000).toISOString();
}
