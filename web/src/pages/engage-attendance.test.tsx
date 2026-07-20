import { describe, expect, it } from 'vitest';
import { screen } from '@testing-library/react';
import { renderWithProviders } from '@/test/utils';
import { AttendanceOverviewPage, AttendanceRegisterPage, AttendanceCorrectionsPage } from '@/pages/attendance/AttendancePages';
import { CommunicationPage, NotificationsPage, ReportsHubPage, OnboardingPage, SchoolConfigPage } from '@/pages/engage/EngagePages';
import { SettingsPage } from '@/pages/settings/SettingsPage';

describe('Attendance module pages', () => {
  it('Overview', () => { renderWithProviders(<AttendanceOverviewPage />); expect(screen.getAllByText('Attendance').length).toBeGreaterThan(0); });
  it('Register', () => { renderWithProviders(<AttendanceRegisterPage />); expect(screen.getAllByText('Register').length).toBeGreaterThan(0); });
  it('Corrections', () => { renderWithProviders(<AttendanceCorrectionsPage />); expect(screen.getByText('Attendance corrections')).toBeInTheDocument(); });
});

describe('Engage / Config pages', () => {
  it('Communication', () => { renderWithProviders(<CommunicationPage />); expect(screen.getByText('Communication')).toBeInTheDocument(); });
  it('Notifications', () => { renderWithProviders(<NotificationsPage />); expect(screen.getAllByText('Notifications').length).toBeGreaterThan(0); });
  it('Reports hub', () => { renderWithProviders(<ReportsHubPage />); expect(screen.getAllByText('Reports').length).toBeGreaterThan(0); });
  it('Onboarding', () => { renderWithProviders(<OnboardingPage />); expect(screen.getByText('Onboarding')).toBeInTheDocument(); });
  it('School config', () => { renderWithProviders(<SchoolConfigPage />); expect(screen.getByText('School setup')).toBeInTheDocument(); });
  it('Settings (theme, client-side)', () => { renderWithProviders(<SettingsPage />); expect(screen.getByText('Appearance')).toBeInTheDocument(); });
});
