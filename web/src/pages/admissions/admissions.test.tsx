import { describe, expect, it } from 'vitest';
import { screen } from '@testing-library/react';
import { renderWithProviders } from '@/test/utils';
import { ApplicationsPage } from './ApplicationsPage';
import { ApprovalPage } from './ApprovalPage';
import { DocumentsPage } from './DocumentsPage';
import { EnrollmentPage } from './EnrollmentPage';
import { AdmissionsReportsPage } from './ReportsPage';
import { AdmissionsSettingsPage } from './SettingsPage';

// Every Admissions page renders its header + an honest state (no fabricated data).
describe('Admissions module pages', () => {
  it('Applications', () => {
    renderWithProviders(<ApplicationsPage />);
    expect(screen.getAllByText('Applications').length).toBeGreaterThan(0);
    expect(screen.getByText(/Applications are ready/i)).toBeInTheDocument();
  });
  it('Approvals', () => {
    renderWithProviders(<ApprovalPage />);
    expect(screen.getByText('Approval queue')).toBeInTheDocument();
  });
  it('Documents', () => {
    renderWithProviders(<DocumentsPage />);
    expect(screen.getAllByText('Documents').length).toBeGreaterThan(0);
  });
  it('Enrolment', () => {
    renderWithProviders(<EnrollmentPage />);
    expect(screen.getAllByText('Enrolment').length).toBeGreaterThan(0);
  });
  it('Reports catalog', () => {
    renderWithProviders(<AdmissionsReportsPage />);
    expect(screen.getByText('Admissions reports')).toBeInTheDocument();
    expect(screen.getByText('Conversion funnel')).toBeInTheDocument();
  });
  it('Settings', () => {
    renderWithProviders(<AdmissionsSettingsPage />);
    expect(screen.getByText('Admissions settings')).toBeInTheDocument();
  });
});
