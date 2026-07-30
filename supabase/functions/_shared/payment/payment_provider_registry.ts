// Provider REGISTRY + school-choice RESOLVER.
//
// The registry maps a provider id → a live PaymentProvider. The resolver reads a
// school's configured provider (payment_provider_config, migration …028) and
// returns the matching implementation, defaulting to 'razorpay' when a school
// has no explicit configuration.
//
// FAIL-CLOSED: an unknown provider id (UnknownPaymentProviderError) or an
// explicitly disabled provider (PaymentProviderDisabledError) throws — the flow
// errors rather than silently falling back and capturing money through a gateway
// the school never chose.

import type { TenantQueryClient } from "../tenant_db.ts";
import {
  type PaymentProvider,
  PaymentProviderDisabledError,
  UnknownPaymentProviderError,
} from "./payment_provider.ts";
import { RAZORPAY_PROVIDER_ID, razorpayProviderFromEnv } from "./razorpay_provider.ts";
import { MANUAL_PROVIDER_ID, ManualProvider } from "./manual_provider.ts";

/** The provider used when a school has no explicit configuration row. */
export const DEFAULT_PROVIDER_ID = RAZORPAY_PROVIDER_ID;

/**
 * The registry. Each entry is a factory so provider config (e.g. Razorpay's env
 * credentials) is read fresh per resolution rather than captured at import time.
 * Adding a gateway = one entry here + one PaymentProvider implementation.
 */
const PROVIDER_FACTORIES: Record<string, () => PaymentProvider> = {
  [RAZORPAY_PROVIDER_ID]: () => razorpayProviderFromEnv(),
  [MANUAL_PROVIDER_ID]: () => new ManualProvider(),
};

/** The provider ids that have a registered implementation. */
export function registeredProviderIds(): string[] {
  return Object.keys(PROVIDER_FACTORIES);
}

/**
 * Registry lookup. Throws UnknownPaymentProviderError (fail-closed) for an id
 * with no implementation — used both for a school's configured id and for
 * resolving the provider that created an intent (intent.gateway).
 */
export function getPaymentProvider(providerId: string): PaymentProvider {
  const factory = PROVIDER_FACTORIES[providerId];
  if (!factory) {
    throw new UnknownPaymentProviderError(providerId);
  }
  return factory();
}

interface ProviderConfigRow {
  provider: string;
  enabled: boolean;
}

/**
 * Read a school's configured provider id from payment_provider_config.
 * - no row            → DEFAULT_PROVIDER_ID ('razorpay')  [config-driven default]
 * - row, enabled=false → throws PaymentProviderDisabledError  [fail-closed]
 * - row, enabled=true  → the configured provider id
 *
 * Note: this returns the id string only; validity of the id (that it maps to a
 * real implementation) is enforced by getPaymentProvider, so a stale/unknown
 * configured id still fails closed at resolution time.
 */
export async function resolveSchoolProviderId(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<string> {
  const rows = await db.queryObject<ProviderConfigRow>(
    `SELECT provider, enabled
       FROM payment_provider_config
      WHERE organization_id = $1
        AND school_id = $2`,
    [organizationId, schoolId],
  );
  const row = rows[0];
  if (!row) {
    return DEFAULT_PROVIDER_ID;
  }
  if (row.enabled === false) {
    throw new PaymentProviderDisabledError(row.provider);
  }
  return row.provider;
}

/**
 * Resolve the PaymentProvider for a school. Combines the config read with the
 * registry lookup so a missing config → default provider, an unknown configured
 * id → UnknownPaymentProviderError, and a disabled provider →
 * PaymentProviderDisabledError. Never returns a fabricated/no-op provider.
 */
export async function resolvePaymentProvider(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<PaymentProvider> {
  const providerId = await resolveSchoolProviderId(db, organizationId, schoolId);
  return getPaymentProvider(providerId);
}
