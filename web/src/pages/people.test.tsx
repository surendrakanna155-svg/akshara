import { describe, expect, it } from 'vitest';
import { screen } from '@testing-library/react';
import { renderWithProviders } from '@/test/utils';
import { EmployeesPage } from '@/pages/hr/EmployeesPage';
import { LeadsPage } from '@/pages/admissions/LeadsPage';
import { AdmissionsDashboardPage } from '@/pages/admissions/AdmissionsDashboardPage';
import { StudentRegistryPage } from '@/pages/sis/StudentRegistryPage';

// With no live backend configured (demo default), every page must render an
// honest "awaiting backend" state — never fabricated data.
describe('People module pages', () => {
  it('HR employees renders header + awaiting-backend state', () => {
    renderWithProviders(<EmployeesPage />);
    expect(screen.getByText('Staff & HR')).toBeInTheDocument();
    expect(screen.getByText(/Employee directory is ready/i)).toBeInTheDocument();
  });

  it('Admission leads renders header + awaiting-backend state', () => {
    renderWithProviders(<LeadsPage />);
    expect(screen.getByText('Admission Leads')).toBeInTheDocument();
    expect(screen.getByText(/Lead pipeline is ready/i)).toBeInTheDocument();
  });

  it('Admissions dashboard renders header + awaiting-backend state', () => {
    renderWithProviders(<AdmissionsDashboardPage />);
    expect(screen.getByText('Admissions')).toBeInTheDocument();
    expect(screen.getByText(/Admissions overview is ready/i)).toBeInTheDocument();
  });

  it('SIS registry renders header + awaiting-backend state', () => {
    renderWithProviders(<StudentRegistryPage />);
    expect(screen.getByText('Students')).toBeInTheDocument();
    expect(screen.getByText(/Student registry is ready/i)).toBeInTheDocument();
  });
});
