import { describe, expect, it } from 'vitest';
import { screen } from '@testing-library/react';
import { renderWithProviders } from '@/test/utils';
import { FinanceDashboardPage } from './FinanceDashboardPage';
import { CollectionsPage } from './CollectionsPage';
import { StudentAccountsPage } from './StudentAccountsPage';
import { FeeStructuresPage } from './FeeStructuresPage';
import { DefaultersPage } from './DefaultersPage';
import { RefundsPage } from './RefundsPage';
import { DiscountsPage } from './DiscountsPage';
import { FinanceReportsPage } from './FinanceReportsPage';
import { FinanceSettingsPage } from './FinanceSettingsPage';

describe('Finance module pages', () => {
  it('Dashboard', () => {
    renderWithProviders(<FinanceDashboardPage />);
    expect(screen.getByText(/Finance overview is ready/i)).toBeInTheDocument();
  });
  it('Collections', () => {
    renderWithProviders(<CollectionsPage />);
    expect(screen.getAllByText('Collections').length).toBeGreaterThan(0);
  });
  it('Student accounts', () => {
    renderWithProviders(<StudentAccountsPage />);
    expect(screen.getAllByText('Student accounts').length).toBeGreaterThan(0);
  });
  it('Fee structures', () => {
    renderWithProviders(<FeeStructuresPage />);
    expect(screen.getAllByText('Fee structures').length).toBeGreaterThan(0);
  });
  it('Defaulters', () => {
    renderWithProviders(<DefaultersPage />);
    expect(screen.getAllByText('Defaulters').length).toBeGreaterThan(0);
  });
  it('Refunds', () => {
    renderWithProviders(<RefundsPage />);
    expect(screen.getAllByText('Refunds').length).toBeGreaterThan(0);
  });
  it('Discounts', () => {
    renderWithProviders(<DiscountsPage />);
    expect(screen.getByText('Discounts & scholarships')).toBeInTheDocument();
  });
  it('Reports', () => {
    renderWithProviders(<FinanceReportsPage />);
    expect(screen.getByText('Finance reports')).toBeInTheDocument();
  });
  it('Settings', () => {
    renderWithProviders(<FinanceSettingsPage />);
    expect(screen.getByText('Finance settings')).toBeInTheDocument();
  });
});
