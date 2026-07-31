import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import type { ReactNode } from 'react';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ThemeProvider } from '@/theme/ThemeProvider';
import { ToastProvider } from '@/components/ui';
import { AuthProvider } from '@/lib/auth/AuthContext';

/**
 * Contract guard for the school-overview dashboard.
 *
 * `GET /dashboard/overview` does NOT return the `DashboardData` shape this page
 * was written against. It returns `DashboardOverview`:
 *   { students, attendanceToday, finance, admissions, recentEnrollments }
 * with no `kpis`, no `enrollmentTrend`, no `feeCollection`, no `attendanceByGrade`,
 * no `activity`, no `approvals`.
 *
 * That mismatch was masked for as long as the endpoint answered 500 — the query
 * errored and AsyncBoundary rendered an error state. Once the endpoint started
 * answering 200, the payload reached the render path, and `d.kpis.students`
 * dereferences undefined. AsyncBoundary is a QUERY-state boundary (loading →
 * error → empty → data); it has no componentDidCatch, so nothing catches it.
 *
 * This test pins the real payload so the page can never again be shipped
 * assuming a shape the backend does not send.
 */

/** Exactly what production returns today (captured from api.nikshaos.in). */
const REAL_PAYLOAD = {
  students: { total: 1, active: 1, inactive: 0, graduated: 0 },
  attendanceToday: { sessionsSubmitted: 0, studentsMarked: '0', attendedEquivalent: '0', percent: null },
  finance: { collectedToday: 0, collectedTodayCount: 0, collectedMtd: 0, collectedMtdCount: 0, outstanding: 0, pendingInvoices: 0 },
  admissions: { pending: 0, recent: 0 },
  recentEnrollments: [],
};

vi.mock('@/lib/api/useModuleQuery', () => ({
  useModuleQuery: () => ({
    data: REAL_PAYLOAD,
    isLoading: false,
    error: null,
    unavailable: false,
  }),
}));

const { DashboardPage } = await import('./DashboardPage');

function renderPage() {
  function Wrapper({ children }: { children: ReactNode }) {
    return (
      <ThemeProvider>
        <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
          <AuthProvider>
            <ToastProvider>
              <MemoryRouter>{children}</MemoryRouter>
            </ToastProvider>
          </AuthProvider>
        </QueryClientProvider>
      </ThemeProvider>
    );
  }
  return render(<DashboardPage />, { wrapper: Wrapper });
}

describe('DashboardPage — live /dashboard/overview contract', () => {
  it('does not crash when the endpoint returns its real (non-DashboardData) shape', () => {
    expect(() => renderPage()).not.toThrow();
  });

  it('shows an honest state rather than fabricated or blank KPIs', () => {
    renderPage();
    // The page must tell the user the overview is not wired yet — never render
    // a KPI card populated from a shape the backend does not send.
    expect(screen.getByText(/School overview is ready/i)).toBeInTheDocument();
  });
});
