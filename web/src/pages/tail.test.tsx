import { describe, expect, it } from 'vitest';
import { screen } from '@testing-library/react';
import { renderWithProviders } from '@/test/utils';
import * as SO from '@/pages/schoolops/SchoolOpsPages';
import * as Misc from '@/pages/misc/MiscPages';
import * as FX from '@/pages/finance/FinanceExtraPages';

describe('School setup & ops pages', () => {
  it('Hub', () => { renderWithProviders(<SO.SchoolCompletionHubPage />); expect(screen.getByText('School setup & operations')).toBeInTheDocument(); });
  it('Subjects', () => { renderWithProviders(<SO.SubjectsPage />); expect(screen.getAllByText('Subjects').length).toBeGreaterThan(0); });
  it('Timetable automation', () => { renderWithProviders(<SO.TimetableAutomationPage />); expect(screen.getByText('Timetable automation')).toBeInTheDocument(); });
  it('Branding', () => { renderWithProviders(<SO.BrandingPage />); expect(screen.getAllByText('Branding').length).toBeGreaterThan(0); });
});

describe('Finance sub-screens', () => {
  it('Fee assignment', () => { renderWithProviders(<FX.FeeAssignmentPage />); expect(screen.getByText('Fee assignment')).toBeInTheDocument(); });
  it('Offline payments', () => { renderWithProviders(<FX.OfflinePaymentsPage />); expect(screen.getByText('Offline payments')).toBeInTheDocument(); });
  it('Executive', () => { renderWithProviders(<FX.FinanceExecutivePage />); expect(screen.getByText('Finance executive')).toBeInTheDocument(); });
});

describe('Misc modules', () => {
  it('Copilot', () => { renderWithProviders(<Misc.CopilotPage />); expect(screen.getAllByText('Akshara Copilot').length).toBeGreaterThan(0); });
  it('Predictions', () => { renderWithProviders(<Misc.PredictionsPage />); expect(screen.getByText('Predictions')).toBeInTheDocument(); });
  it('Admin hub', () => { renderWithProviders(<Misc.AdminHubPage />); expect(screen.getAllByText('Admin').length).toBeGreaterThan(0); });
  it('Legal', () => { renderWithProviders(<Misc.LegalAcceptancePage />); expect(screen.getByText('Policies')).toBeInTheDocument(); });
  it('Parent meetings', () => { renderWithProviders(<Misc.ParentMeetingsPage />); expect(screen.getByText('Parent meetings')).toBeInTheDocument(); });
});
