import { describe, expect, it } from 'vitest';
import { screen } from '@testing-library/react';
import { renderWithProviders } from '@/test/utils';
import * as M from '@/pages/management/ManagementPages';
import * as D from '@/pages/director/DirectorPages';
import * as I from '@/pages/intelligence/IntelligencePages';

describe('Management module pages', () => {
  it('Dashboard', () => { renderWithProviders(<M.ManagementDashboardPage />); expect(screen.getAllByText('Management').length).toBeGreaterThan(0); });
  it('Analytics', () => { renderWithProviders(<M.ManagementAnalyticsPage />); expect(screen.getAllByText('Analytics').length).toBeGreaterThan(0); });
  it('Approvals', () => { renderWithProviders(<M.ApprovalCenterPage />); expect(screen.getByText('Approval center')).toBeInTheDocument(); });
  it('Settings', () => { renderWithProviders(<M.ManagementSettingsPage />); expect(screen.getByText('Management settings')).toBeInTheDocument(); });
});

describe('Director module pages', () => {
  it('Dashboard', () => { renderWithProviders(<D.DirectorDashboardPage />); expect(screen.getAllByText('Director').length).toBeGreaterThan(0); });
  it('Revenue', () => { renderWithProviders(<D.DirectorRevenuePage />); expect(screen.getAllByText('Revenue').length).toBeGreaterThan(0); });
  it('Compliance', () => { renderWithProviders(<D.DirectorCompliancePage />); expect(screen.getAllByText('Compliance').length).toBeGreaterThan(0); });
});

describe('Intelligence module pages', () => {
  it('Hub', () => { renderWithProviders(<I.IntelligenceHubPage />); expect(screen.getAllByText('Intelligence').length).toBeGreaterThan(0); });
  it('Student success', () => { renderWithProviders(<I.StudentSuccessPage />); expect(screen.getByText('Student success')).toBeInTheDocument(); });
  it('Trust (WEB-006 gap shell)', () => { renderWithProviders(<I.TrustIntelligencePage />); expect(screen.getByText(/WEB-006/i)).toBeInTheDocument(); });
});
