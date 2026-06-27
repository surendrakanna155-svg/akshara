import type { AccessTokenClaims, AuthScope } from "../jwt.ts";

/**
 * Single source of truth for the legal policies the app enforces, and which ones
 * each kind of user must accept. Keep the `version` values in sync with the
 * document headers and `docs/legal/CHANGELOG.md` — bumping a version here is what
 * forces re-acceptance in the app on the next launch.
 *
 * Hosting note: `path` is the public sub-path each policy will live at once the
 * owner hosts the documents (see docs/legal/PLACEHOLDERS.md). The Flutter client
 * resolves the full URL against the configured policy host; an unhosted policy
 * simply shows its summary without a working "view full policy" link.
 */
export interface PolicyDefinition {
  key: string;
  title: string;
  version: string;
  /** Plain-language one-line summary shown on the acceptance screen. */
  summary: string;
  /** Public sub-path (joined to the configured policy host) once hosted. */
  path: string;
}

export const LEGAL_POLICIES: Record<string, PolicyDefinition> = {
  privacy: {
    key: "privacy",
    title: "Privacy Policy",
    version: "2.0",
    summary:
      "How we handle your and your child's data. We never sell data or advertise to children.",
    path: "/privacy",
  },
  user_terms: {
    key: "user_terms",
    title: "Parent & User Terms",
    version: "1.0",
    summary:
      "The basic rules for using the app. Your school is the owner of your child's records.",
    path: "/terms/user",
  },
  acceptable_use: {
    key: "acceptable_use",
    title: "Acceptable Use Policy",
    version: "1.0",
    summary:
      "Use the platform only for genuine school purposes and only access data you are authorised to see.",
    path: "/terms/acceptable-use",
  },
  institution_agreement: {
    key: "institution_agreement",
    title: "School / Institution Agreement",
    version: "1.0",
    summary:
      "The agreement (incl. data-processing terms) between your school and Akshara. Accept on the school's behalf.",
    path: "/terms/institution",
  },
};

/** A small public view of a policy, returned to the client. */
export interface PolicyView {
  key: string;
  title: string;
  version: string;
  summary: string;
  path: string;
}

export function toPolicyView(def: PolicyDefinition): PolicyView {
  return {
    key: def.key,
    title: def.title,
    version: def.version,
    summary: def.summary,
    path: def.path,
  };
}

/** True when the role slug looks like a school administrator / leader. */
function isAdminRole(roleSlug: string): boolean {
  const r = roleSlug.toLowerCase();
  return (
    r.includes("principal") ||
    r.includes("admin") ||
    r.includes("director") ||
    r.includes("owner") ||
    r.includes("founder") ||
    r.includes("head")
  );
}

/**
 * The policy keys a given user MUST accept, by scope and role. Students are not
 * gated — their lawful basis is the school's responsibility under parental consent
 * (see docs/legal/CHILDREN_DATA_AND_CONSENT.md). Internal platform operators are
 * not gated either.
 */
export function requiredPolicyKeys(
  scope: AuthScope,
  primaryRole: string,
): string[] {
  switch (scope) {
    case "parent":
      return ["privacy", "user_terms"];
    case "student":
    case "platform":
      return [];
    case "organization":
    case "school_group":
      // Director / chain leadership accept on the organisation's behalf.
      return ["privacy", "acceptable_use", "institution_agreement"];
    case "school": {
      const base = ["privacy", "acceptable_use"];
      if (isAdminRole(primaryRole)) base.push("institution_agreement");
      return base;
    }
    default:
      return ["privacy"];
  }
}

export function requiredPolicyKeysForClaims(claims: AccessTokenClaims): string[] {
  return requiredPolicyKeys(claims.scope, claims.primary_role);
}

export interface OutstandingPolicy extends PolicyView {}

/**
 * Given the policies a user must accept and the (key→acceptedVersion) map of what
 * they've already accepted, return the policies still outstanding at the CURRENT
 * version. A previously-accepted older version counts as outstanding (re-accept).
 */
export function computeOutstanding(
  requiredKeys: string[],
  acceptedVersionsByKey: Map<string, Set<string>>,
): OutstandingPolicy[] {
  const outstanding: OutstandingPolicy[] = [];
  for (const key of requiredKeys) {
    const def = LEGAL_POLICIES[key];
    if (!def) continue;
    const accepted = acceptedVersionsByKey.get(key);
    if (!accepted || !accepted.has(def.version)) {
      outstanding.push(toPolicyView(def));
    }
  }
  return outstanding;
}
