import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  type DomainEventInput,
  enqueueDomainEvent,
  recordMutationAudit,
  type ServerAuditInput,
} from "./audit_repository.ts";

export type { DomainEventInput, ServerAuditInput };

export async function withMutationAudit<T>(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  req: Request | undefined,
  audit: ServerAuditInput,
  domainEvent: DomainEventInput | null,
  operation: () => Promise<T>,
): Promise<T> {
  const result = await operation();
  await recordMutationAudit(db, claims, audit, domainEvent, req);
  return result;
}

export { enqueueDomainEvent, recordMutationAudit };
