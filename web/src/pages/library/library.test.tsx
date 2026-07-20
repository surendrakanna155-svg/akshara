import { describe, expect, it } from 'vitest';
import { screen } from '@testing-library/react';
import { renderWithProviders } from '@/test/utils';
import { LibraryDashboardPage } from './LibraryDashboardPage';
import { CatalogPage } from './CatalogPage';
import { IssuesPage, OverduePage } from './IssuesPage';
import { ReturnsPage } from './ReturnsPage';
import { MembersPage } from './MembersPage';
import { FinesPage } from './FinesPage';
import { ResourcesPage } from './ResourcesPage';
import { LibraryReportsPage } from './LibraryReportsPage';

describe('Library module pages', () => {
  it('Dashboard', () => { renderWithProviders(<LibraryDashboardPage />); expect(screen.getByText(/Library overview is ready/i)).toBeInTheDocument(); });
  it('Catalog', () => { renderWithProviders(<CatalogPage />); expect(screen.getAllByText('Catalog').length).toBeGreaterThan(0); });
  it('Issues', () => { renderWithProviders(<IssuesPage />); expect(screen.getAllByText('Issues').length).toBeGreaterThan(0); });
  it('Overdue', () => { renderWithProviders(<OverduePage />); expect(screen.getAllByText('Overdue').length).toBeGreaterThan(0); });
  it('Returns', () => { renderWithProviders(<ReturnsPage />); expect(screen.getAllByText('Returns').length).toBeGreaterThan(0); });
  it('Members', () => { renderWithProviders(<MembersPage />); expect(screen.getAllByText('Members').length).toBeGreaterThan(0); });
  it('Fines', () => { renderWithProviders(<FinesPage />); expect(screen.getAllByText('Fines').length).toBeGreaterThan(0); });
  it('Resources', () => { renderWithProviders(<ResourcesPage />); expect(screen.getByText('Digital resources')).toBeInTheDocument(); });
  it('Reports', () => { renderWithProviders(<LibraryReportsPage />); expect(screen.getByText('Library reports')).toBeInTheDocument(); });
});
