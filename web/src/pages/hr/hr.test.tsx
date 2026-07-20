import { describe, expect, it } from 'vitest';
import { screen } from '@testing-library/react';
import { renderWithProviders } from '@/test/utils';
import { HrDashboardPage } from './HrDashboardPage';
import { HrAttendancePage } from './AttendancePage';
import { HrLeavePage } from './LeavePage';
import { HrPayrollPage } from './PayrollPage';
import { HrRecruitmentPage } from './RecruitmentPage';
import { HrPerformancePage } from './PerformancePage';
import { HrReportsPage } from './HrReportsPage';
import { HrSettingsPage } from './HrSettingsPage';

describe('HR module pages', () => {
  it('Dashboard', () => {
    renderWithProviders(<HrDashboardPage />);
    expect(screen.getByText(/Workforce overview is ready/i)).toBeInTheDocument();
  });
  it('Attendance', () => {
    renderWithProviders(<HrAttendancePage />);
    expect(screen.getByText('Staff attendance')).toBeInTheDocument();
  });
  it('Leave', () => {
    renderWithProviders(<HrLeavePage />);
    expect(screen.getByText('Leave requests')).toBeInTheDocument();
  });
  it('Payroll', () => {
    renderWithProviders(<HrPayrollPage />);
    expect(screen.getAllByText('Payroll').length).toBeGreaterThan(0);
  });
  it('Recruitment', () => {
    renderWithProviders(<HrRecruitmentPage />);
    expect(screen.getAllByText('Recruitment').length).toBeGreaterThan(0);
  });
  it('Performance', () => {
    renderWithProviders(<HrPerformancePage />);
    expect(screen.getAllByText('Performance').length).toBeGreaterThan(0);
  });
  it('Reports', () => {
    renderWithProviders(<HrReportsPage />);
    expect(screen.getByText('HR reports')).toBeInTheDocument();
  });
  it('Settings', () => {
    renderWithProviders(<HrSettingsPage />);
    expect(screen.getByText('HR settings')).toBeInTheDocument();
  });
});
