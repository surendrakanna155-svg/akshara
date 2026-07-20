/**
 * Shared presentational bits for the Support Console. No data fetching here —
 * these render the (already-snapshotted) evidence payloads readably.
 */
import { useMemo, useState } from 'react';
import { Card, Text, Button } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { cn } from '@/lib/utils/cn';
import { formatDateTime, humanize } from '@/lib/utils/format';

const EVIDENCE_ICON: Record<string, string> = {
  context: 'devices',
  audit_events: 'history',
  api_calls: 'sync_alt',
  workflow_state: 'account_tree',
  diagnostics: 'monitor_heart',
};

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return !!v && typeof v === 'object' && !Array.isArray(v);
}

function isPrimitive(v: unknown): v is string | number | boolean {
  return v === null || ['string', 'number', 'boolean'].includes(typeof v);
}

function primitiveText(v: unknown): string {
  if (v === null || v === undefined) return '—';
  if (typeof v === 'boolean') return v ? 'true' : 'false';
  return String(v);
}

/** Pretty, scrollable, monospaced JSON — the raw fallback / copy target. */
export function JsonBlock({ value, className }: { value: unknown; className?: string }) {
  const text = useMemo(() => {
    try {
      return JSON.stringify(value, null, 2);
    } catch {
      return String(value);
    }
  }, [value]);
  return (
    <pre
      className={cn(
        'max-h-80 overflow-auto rounded-md border border-outline-variant/60 bg-surface-low p-s3 ak-mono text-[12px] leading-relaxed text-on-surface',
        className,
      )}
    >
      {text}
    </pre>
  );
}

/** A single label → scalar row. */
export function KeyValue({ label, value, icon }: { label: string; value: React.ReactNode; icon?: string }) {
  return (
    <div className="flex items-start gap-s2">
      {icon && <Icon name={icon} size={18} className="mt-[2px] text-on-surface-variant" />}
      <div className="min-w-0">
        <Text variant="label-md" className="text-on-surface-variant">
          {label}
        </Text>
        <div className="ak-body-md break-words text-on-surface">{value}</div>
      </div>
    </div>
  );
}

/** Renders an object's scalar fields as a KV grid; nested values fall back to JSON. */
function ObjectGrid({ data }: { data: Record<string, unknown> }) {
  const entries = Object.entries(data);
  const scalars = entries.filter(([, v]) => isPrimitive(v));
  const complex = entries.filter(([, v]) => !isPrimitive(v));
  return (
    <div className="space-y-s3">
      {scalars.length > 0 && (
        <dl className="grid grid-cols-1 gap-s3 sm:grid-cols-2">
          {scalars.map(([k, v]) => (
            <KeyValue key={k} label={humanize(k)} value={<span className={typeof v === 'string' && /id$|_id$|ref/i.test(k) ? 'ak-mono text-[12px]' : ''}>{primitiveText(v)}</span>} />
          ))}
        </dl>
      )}
      {complex.map(([k, v]) => (
        <div key={k}>
          <Text variant="label-md" className="mb-s1 text-on-surface-variant">
            {humanize(k)}
          </Text>
          <ReadableValue value={v} />
        </div>
      ))}
    </div>
  );
}

/** Recursively renders an arbitrary snapshot value in a readable way. */
export function ReadableValue({ value }: { value: unknown }) {
  if (isPrimitive(value)) return <span className="ak-body-md text-on-surface">{primitiveText(value)}</span>;
  if (Array.isArray(value)) {
    if (value.length === 0) return <Text variant="body-sm" className="italic text-on-surface-variant">None</Text>;
    if (value.every(isPrimitive)) {
      return (
        <div className="flex flex-wrap gap-s1">
          {value.map((v, i) => (
            <span key={i} className="rounded-sm bg-surface-highest px-s2 py-[2px] ak-mono text-[12px] text-on-surface-variant">
              {primitiveText(v)}
            </span>
          ))}
        </div>
      );
    }
    return (
      <div className="space-y-s2">
        {value.map((v, i) => (
          <div key={i} className="rounded-md border border-outline-variant/50 bg-surface-low p-s3">
            <ReadableValue value={v} />
          </div>
        ))}
      </div>
    );
  }
  if (isPlainObject(value)) return <ObjectGrid data={value} />;
  return <JsonBlock value={value} />;
}

/** One evidence snapshot rendered readably, with a raw-JSON toggle. */
export function EvidenceCard({ kind, payload, collectedAt }: { kind: string; payload: unknown; collectedAt: string }) {
  const [raw, setRaw] = useState(false);
  const empty = payload == null || (Array.isArray(payload) && payload.length === 0) || (isPlainObject(payload) && Object.keys(payload).length === 0);
  return (
    <Card padded={false}>
      <div className="flex items-center justify-between gap-s3 border-b border-outline-variant/60 px-s4 py-s3">
        <div className="flex items-center gap-s3">
          <span className="grid h-9 w-9 place-items-center rounded-md bg-primary-container text-on-primary-container">
            <Icon name={EVIDENCE_ICON[kind] ?? 'description'} size={18} />
          </span>
          <div>
            <Text variant="title-sm" className="text-on-surface">
              {humanize(kind)}
            </Text>
            {collectedAt && (
              <Text variant="body-sm" className="text-on-surface-variant">
                Collected {formatDateTime(collectedAt)}
              </Text>
            )}
          </div>
        </div>
        <Button size="sm" variant="text" icon={raw ? 'view_agenda' : 'data_object'} onClick={() => setRaw((r) => !r)}>
          {raw ? 'Readable' : 'Raw'}
        </Button>
      </div>
      <div className="p-s4">
        {empty ? (
          <Text variant="body-sm" className="italic text-on-surface-variant">
            No {humanize(kind).toLowerCase()} captured for this incident.
          </Text>
        ) : raw ? (
          <JsonBlock value={payload} />
        ) : (
          <ReadableValue value={payload} />
        )}
      </div>
    </Card>
  );
}

/** A small labelled pill used in the incident header. */
export function MetaPill({ icon, label, value }: { icon: string; label: string; value: React.ReactNode }) {
  return (
    <div className="flex items-center gap-s2 rounded-md border border-outline-variant/60 bg-surface-low px-s3 py-s2">
      <Icon name={icon} size={18} className="text-on-surface-variant" />
      <div className="min-w-0">
        <div className="ak-label-sm uppercase tracking-wide text-on-surface-variant/80">{label}</div>
        <div className="ak-label-lg truncate text-on-surface">{value}</div>
      </div>
    </div>
  );
}

/** AI-suggested banner — makes the human-approves rule visually explicit. */
export function AiSuggestedBanner() {
  return (
    <div className="flex items-start gap-s2 rounded-md border border-indigo/30 bg-indigo-container/60 px-s3 py-s2">
      <Icon name="auto_awesome" size={18} className="mt-[1px] text-indigo" />
      <Text variant="body-sm" className="text-on-surface">
        <span className="font-semibold text-indigo">AI-suggested draft.</span> Generated from the incident evidence to
        speed up triage. Review before acting — a human support engineer decides and applies every action.
      </Text>
    </div>
  );
}
