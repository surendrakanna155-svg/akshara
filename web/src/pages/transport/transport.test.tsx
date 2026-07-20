import { describe, expect, it } from 'vitest';
import { screen } from '@testing-library/react';
import { renderWithProviders } from '@/test/utils';
import { TransportDashboardPage } from './TransportDashboardPage';
import { RoutesPage } from './RoutesPage';
import { VehiclesPage } from './VehiclesPage';
import { DriversPage } from './DriversPage';
import { AllocationsPage } from './AllocationsPage';
import { TransportAttendancePage } from './TransportAttendancePage';
import { TrackingPage } from './TrackingPage';
import { TransportReportsPage } from './TransportReportsPage';
import { TransportSettingsPage } from './TransportSettingsPage';

describe('Transport module pages', () => {
  it('Dashboard', () => {
    renderWithProviders(<TransportDashboardPage />);
    expect(screen.getByText(/Transport overview is ready/i)).toBeInTheDocument();
  });
  it('Routes', () => { renderWithProviders(<RoutesPage />); expect(screen.getAllByText('Routes').length).toBeGreaterThan(0); });
  it('Vehicles', () => { renderWithProviders(<VehiclesPage />); expect(screen.getAllByText('Vehicles').length).toBeGreaterThan(0); });
  it('Drivers', () => { renderWithProviders(<DriversPage />); expect(screen.getAllByText('Drivers').length).toBeGreaterThan(0); });
  it('Allocations', () => { renderWithProviders(<AllocationsPage />); expect(screen.getAllByText('Allocations').length).toBeGreaterThan(0); });
  it('Attendance', () => { renderWithProviders(<TransportAttendancePage />); expect(screen.getByText('Transport attendance')).toBeInTheDocument(); });
  it('Tracking (GPS gap shell)', () => { renderWithProviders(<TrackingPage />); expect(screen.getByText(/Phase-2 integration/i)).toBeInTheDocument(); });
  it('Reports', () => { renderWithProviders(<TransportReportsPage />); expect(screen.getByText('Transport reports')).toBeInTheDocument(); });
  it('Settings', () => { renderWithProviders(<TransportSettingsPage />); expect(screen.getByText('Transport settings')).toBeInTheDocument(); });
});
