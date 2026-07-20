import { describe, expect, it } from 'vitest';
import { screen } from '@testing-library/react';
import { renderWithProviders } from '@/test/utils';
import * as Inv from './InventoryPages';

describe('Inventory module pages', () => {
  it('Dashboard', () => { renderWithProviders(<Inv.InventoryDashboardPage />); expect(screen.getByText(/Inventory overview is ready/i)).toBeInTheDocument(); });
  it('Stock (gap shell)', () => { renderWithProviders(<Inv.StockPage />); expect(screen.getAllByText(/WEB-004/i).length).toBeGreaterThan(0); });
  it('Stock approvals (gap shell)', () => { renderWithProviders(<Inv.StockApprovalsPage />); expect(screen.getByText('Stock approvals')).toBeInTheDocument(); });
  it('Assets', () => { renderWithProviders(<Inv.AssetsPage />); expect(screen.getAllByText('Assets').length).toBeGreaterThan(0); });
  it('Categories', () => { renderWithProviders(<Inv.CategoriesPage />); expect(screen.getAllByText('Categories').length).toBeGreaterThan(0); });
  it('Allocations', () => { renderWithProviders(<Inv.InvAllocationsPage />); expect(screen.getAllByText('Allocations').length).toBeGreaterThan(0); });
  it('Distribution', () => { renderWithProviders(<Inv.DistributionPage />); expect(screen.getAllByText('Distribution').length).toBeGreaterThan(0); });
  it('Maintenance', () => { renderWithProviders(<Inv.MaintenancePage />); expect(screen.getAllByText('Maintenance').length).toBeGreaterThan(0); });
  it('Replacement', () => { renderWithProviders(<Inv.ReplacementPage />); expect(screen.getAllByText('Replacement').length).toBeGreaterThan(0); });
  it('Procurement', () => { renderWithProviders(<Inv.ProcurementPage />); expect(screen.getAllByText('Procurement').length).toBeGreaterThan(0); });
  it('Vendors', () => { renderWithProviders(<Inv.VendorsPage />); expect(screen.getAllByText('Vendors').length).toBeGreaterThan(0); });
  it('Lifecycle', () => { renderWithProviders(<Inv.LifecyclePage />); expect(screen.getByText('Asset lifecycle')).toBeInTheDocument(); });
  it('Copilot', () => { renderWithProviders(<Inv.InventoryCopilotPage />); expect(screen.getByText('Inventory copilot')).toBeInTheDocument(); });
  it('Reports', () => { renderWithProviders(<Inv.InventoryReportsPage />); expect(screen.getByText('Inventory reports')).toBeInTheDocument(); });
});
