import { describe, expect, it } from 'vitest';
import { screen } from '@testing-library/react';
import { renderWithProviders } from '@/test/utils';
import {
  normalizeIncident,
  normalizeIncidentDetail,
  normalizeInvestigation,
  severityMeta,
  supportStatusMeta,
} from '@/lib/contracts/support';
import { SupportConsoleGate } from './shell';
import { SupportQueuePage } from './SupportQueuePage';
import { SupportIncidentPage } from './SupportIncidentPage';
import { SupportClustersPage } from './SupportClustersPage';
import { SupportClusterDetailPage } from './SupportClusterDetailPage';

describe('Support Console — render (demo/no-backend honest states)', () => {
  it('Gate requires a live platform-support session', () => {
    renderWithProviders(<SupportConsoleGate />);
    expect(screen.getByText(/Akshara Support Console/i)).toBeInTheDocument();
    expect(screen.getByText(/platform-support session/i)).toBeInTheDocument();
  });

  it('Queue page mounts with header + section nav + awaiting-backend state', () => {
    renderWithProviders(<SupportQueuePage />);
    expect(screen.getByText('Support Console')).toBeInTheDocument();
    expect(screen.getByText('Incident queue')).toBeInTheDocument();
    expect(screen.getByText('Clusters')).toBeInTheDocument();
    expect(screen.getByText(/Support queue is ready/i)).toBeInTheDocument();
  });

  it('Incident workspace mounts with its awaiting-backend state', () => {
    renderWithProviders(<SupportIncidentPage />, { route: '/support-console/incidents/abc' });
    expect(screen.getByText('Incident workspace')).toBeInTheDocument();
    expect(screen.getByText(/Incident workspace is ready/i)).toBeInTheDocument();
  });

  it('Clusters list mounts', () => {
    renderWithProviders(<SupportClustersPage />);
    expect(screen.getByText(/Clusters are ready/i)).toBeInTheDocument();
  });

  it('Cluster detail mounts', () => {
    renderWithProviders(<SupportClusterDetailPage />, { route: '/support-console/clusters/c1' });
    expect(screen.getByText(/Cluster detail is ready/i)).toBeInTheDocument();
  });
});

describe('Support Console — contract normalizers', () => {
  it('maps snake_case incident fields to camelCase', () => {
    const inc = normalizeIncident({
      id: 'i1',
      source_org_id: 'org1',
      source_school_id: 'sch1',
      public_ref: 'SUP-1001',
      title: 'Cannot save marks',
      description: 'Fails on submit',
      category: 'data_error',
      severity: 'sev2',
      source_status: 'triaging',
      module_key: 'academics',
      screen_route: '/academics/exams/marks-entry',
      app_version: '1.4.0',
      platform: 'android',
      support_status: 'investigating',
      assigned_to: null,
      escalated_at: null,
      cluster_id: 'cl1',
      first_seen_at: '2026-07-20T10:00:00Z',
      mirrored_at: '2026-07-20T10:01:00Z',
      updated_at: '2026-07-20T10:05:00Z',
    });
    expect(inc.publicRef).toBe('SUP-1001');
    expect(inc.moduleKey).toBe('academics');
    expect(inc.supportStatus).toBe('investigating');
    expect(inc.assignedTo).toBeNull();
    expect(inc.clusterId).toBe('cl1');
  });

  it('defaults support_status to queue and shapes the detail composite', () => {
    const detail = normalizeIncidentDetail({
      incident: { id: 'i2', public_ref: 'SUP-2' },
      evidence: [{ kind: 'context', payload: { app_version: '1.4.0' }, collected_at: '2026-07-20T00:00:00Z' }],
      notes: [{ id: 'n1', author_user_id: 'u1', body: 'looking', created_at: '2026-07-20T00:00:00Z' }],
      cluster: null,
    });
    expect(detail.incident.supportStatus).toBe('queue');
    expect(detail.evidence).toHaveLength(1);
    expect(detail.notes[0].body).toBe('looking');
    expect(detail.cluster).toBeNull();
  });

  it('tolerates camelCase investigation payloads', () => {
    const r = normalizeInvestigation({
      summary: 'Widespread submit failure',
      likelyRootCause: 'Null marks_grid on server',
      recommendedFix: 'Guard the writer',
      confidence: 0.8,
      method: 'ai_enriched',
      model: 'claude',
      clusterSize: 4,
    });
    expect(r.likelyRootCause).toContain('marks_grid');
    expect(r.method).toBe('ai_enriched');
    expect(r.clusterSize).toBe(4);
  });

  it('exposes semantic metadata for status + severity', () => {
    expect(supportStatusMeta('awaiting_engineering').label).toBe('Awaiting engineering');
    expect(supportStatusMeta('resolved').status).toBe('success');
    expect(severityMeta('sev1').status).toBe('error');
    expect(severityMeta('sev4').status).toBe('neutral');
  });
});
