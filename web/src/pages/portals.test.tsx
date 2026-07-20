import { describe, expect, it } from 'vitest';
import { screen } from '@testing-library/react';
import { renderWithProviders } from '@/test/utils';
import * as S from '@/pages/student/StudentPages';
import * as T from '@/pages/teacher/TeacherPages';
import * as P from '@/pages/parent/ParentPages';

describe('Student portal', () => {
  it('Dashboard', () => { renderWithProviders(<S.StudentDashboardPage />); expect(screen.getByText('My dashboard')).toBeInTheDocument(); });
  it('Attendance', () => { renderWithProviders(<S.StudentAttendancePage />); expect(screen.getAllByText('Attendance').length).toBeGreaterThan(0); });
  it('Exams', () => { renderWithProviders(<S.StudentExamsPage />); expect(screen.getAllByText('Exams').length).toBeGreaterThan(0); });
  it('Report card', () => { renderWithProviders(<S.StudentReportCardPage />); expect(screen.getByText('Report card')).toBeInTheDocument(); });
});

describe('Teacher portal', () => {
  it('Today', () => { renderWithProviders(<T.TeacherTodayPage />); expect(screen.getByText('Today')).toBeInTheDocument(); });
  it('Attendance', () => { renderWithProviders(<T.TeacherAttendancePage />); expect(screen.getAllByText('Attendance').length).toBeGreaterThan(0); });
  it('Homework create form', () => { renderWithProviders(<T.TeacherHomeworkCreatePage />); expect(screen.getByText('Assign homework')).toBeInTheDocument(); });
  it('Student risk', () => { renderWithProviders(<T.TeacherStudentRiskPage />); expect(screen.getByText('Student risk')).toBeInTheDocument(); });
});

describe('Parent portal', () => {
  it('Home', () => { renderWithProviders(<P.ParentDashboardPage />); expect(screen.getByText('Home')).toBeInTheDocument(); });
  it('Fees', () => { renderWithProviders(<P.ParentFeesPage />); expect(screen.getAllByText('Fees').length).toBeGreaterThan(0); });
  it('Payment', () => { renderWithProviders(<P.ParentPaymentPage />); expect(screen.getByText('Pay fees')).toBeInTheDocument(); });
  it('Receipts', () => { renderWithProviders(<P.ParentReceiptsPage />); expect(screen.getAllByText('Receipts').length).toBeGreaterThan(0); });
});
