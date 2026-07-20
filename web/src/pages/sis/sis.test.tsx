import { describe, expect, it } from 'vitest';
import { screen } from '@testing-library/react';
import { renderWithProviders } from '@/test/utils';
import * as S from './SisPages';

describe('SIS module pages', () => {
  it('Dashboard', () => { renderWithProviders(<S.SisDashboardPage />); expect(screen.getByText(/SIS overview is ready/i)).toBeInTheDocument(); });
  it('Transfers', () => { renderWithProviders(<S.TransfersPage />); expect(screen.getByText('Transfers & exits')).toBeInTheDocument(); });
  it('Admissions conversion', () => { renderWithProviders(<S.AdmissionsConversionPage />); expect(screen.getByText('Admissions conversion')).toBeInTheDocument(); });
  it('Promotion (workflow, WEB-005 gated)', () => { renderWithProviders(<S.PromotionPage />); expect(screen.getAllByText('Promotion').length).toBeGreaterThan(0); });
  it('Reshuffle', () => { renderWithProviders(<S.ReshufflePage />); expect(screen.getAllByText('Reshuffle').length).toBeGreaterThan(0); });
  it('Section balance', () => { renderWithProviders(<S.SectionBalancePage />); expect(screen.getByText('Section balance')).toBeInTheDocument(); });
  it('Academic assignment', () => { renderWithProviders(<S.AcademicAssignmentPage />); expect(screen.getByText('Academic assignment')).toBeInTheDocument(); });
});
