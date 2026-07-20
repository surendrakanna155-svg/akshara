import { describe, expect, it } from 'vitest';
import { screen } from '@testing-library/react';
import { renderWithProviders } from '@/test/utils';
import {
  HostelDashboardPage,
  HostelStudentsPage,
  RoomsPage,
  HostelAttendancePage,
  HostelLeavePage,
  VisitorsPage,
  MessPage,
  HostelReportsPage,
} from './HostelPages';

describe('Hostel module pages', () => {
  it('Dashboard', () => { renderWithProviders(<HostelDashboardPage />); expect(screen.getByText(/Hostel overview is ready/i)).toBeInTheDocument(); });
  it('Residents', () => { renderWithProviders(<HostelStudentsPage />); expect(screen.getAllByText('Residents').length).toBeGreaterThan(0); });
  it('Rooms', () => { renderWithProviders(<RoomsPage />); expect(screen.getAllByText('Rooms').length).toBeGreaterThan(0); });
  it('Attendance', () => { renderWithProviders(<HostelAttendancePage />); expect(screen.getByText('Hostel attendance')).toBeInTheDocument(); });
  it('Leave', () => { renderWithProviders(<HostelLeavePage />); expect(screen.getByText('Leave & gate pass')).toBeInTheDocument(); });
  it('Mess', () => { renderWithProviders(<MessPage />); expect(screen.getAllByText('Mess').length).toBeGreaterThan(0); });
  it('Visitors', () => { renderWithProviders(<VisitorsPage />); expect(screen.getAllByText('Visitors').length).toBeGreaterThan(0); });
  it('Reports', () => { renderWithProviders(<HostelReportsPage />); expect(screen.getByText('Hostel reports')).toBeInTheDocument(); });
});
