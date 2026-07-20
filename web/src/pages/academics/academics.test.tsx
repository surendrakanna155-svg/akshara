import { describe, expect, it } from 'vitest';
import { screen } from '@testing-library/react';
import { renderWithProviders } from '@/test/utils';
import * as Ac from './AcademicsPages';

describe('Academics module pages', () => {
  it('Exam administration', () => { renderWithProviders(<Ac.ExamAdministrationPage />); expect(screen.getAllByText('Examinations').length).toBeGreaterThan(0); });
  it('Marks progress', () => { renderWithProviders(<Ac.ExamMarksProgressPage />); expect(screen.getByText('Marks progress')).toBeInTheDocument(); });
  it('Marks entry', () => { renderWithProviders(<Ac.ExamMarksEntryPage />); expect(screen.getByText('Marks entry')).toBeInTheDocument(); });
  it('Exam reports', () => { renderWithProviders(<Ac.ExamReportsPage />); expect(screen.getByText('Exam reports')).toBeInTheDocument(); });
  it('Timetable', () => { renderWithProviders(<Ac.TimetableHubPage />); expect(screen.getAllByText('Timetable').length).toBeGreaterThan(0); });
  it('Substitutions', () => { renderWithProviders(<Ac.DailySubstitutionsPage />); expect(screen.getByText('Daily substitutions')).toBeInTheDocument(); });
});
