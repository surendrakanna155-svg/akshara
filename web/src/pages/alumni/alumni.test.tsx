import { describe, expect, it } from 'vitest';
import { screen } from '@testing-library/react';
import { renderWithProviders } from '@/test/utils';
import * as A from './AlumniPages';

describe('Alumni module pages', () => {
  it('Dashboard', () => { renderWithProviders(<A.AlumniDashboardPage />); expect(screen.getByText(/Alumni overview is ready/i)).toBeInTheDocument(); });
  it('Registry', () => { renderWithProviders(<A.RegistryPage />); expect(screen.getByText('Alumni registry')).toBeInTheDocument(); });
  it('Campaigns', () => { renderWithProviders(<A.CampaignsPage />); expect(screen.getAllByText('Campaigns').length).toBeGreaterThan(0); });
  it('Donations', () => { renderWithProviders(<A.DonationsPage />); expect(screen.getAllByText('Donations').length).toBeGreaterThan(0); });
  it('Events', () => { renderWithProviders(<A.EventsPage />); expect(screen.getAllByText('Events').length).toBeGreaterThan(0); });
  it('Mentorship', () => { renderWithProviders(<A.MentorshipPage />); expect(screen.getAllByText('Mentorship').length).toBeGreaterThan(0); });
  it('Reports', () => { renderWithProviders(<A.AlumniReportsPage />); expect(screen.getByText('Alumni reports')).toBeInTheDocument(); });
  it('Settings', () => { renderWithProviders(<A.AlumniSettingsPage />); expect(screen.getByText('Alumni settings')).toBeInTheDocument(); });
});
