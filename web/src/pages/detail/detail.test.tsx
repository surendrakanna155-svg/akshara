import { describe, expect, it } from 'vitest';
import { screen } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { render } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ThemeProvider } from '@/theme/ThemeProvider';
import { AuthProvider } from '@/lib/auth/AuthContext';
import { SisStudentDetailPage, CollectionDetailPage, LeadDetailPage, ReceiptDetailPage, TeacherConversationPage } from './DetailPages';

function renderAt(path: string, pattern: string, el: React.ReactElement) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <ThemeProvider><QueryClientProvider client={client}><AuthProvider>
      <MemoryRouter initialEntries={[path]}><Routes><Route path={pattern} element={el} /></Routes></MemoryRouter>
    </AuthProvider></QueryClientProvider></ThemeProvider>,
  );
}

describe('Detail pages (deep-linkable, :id routes)', () => {
  it('SIS student profile', () => { renderAt('/sis/students/abc', '/sis/students/:id', <SisStudentDetailPage />); expect(screen.getByText('Student profile')).toBeInTheDocument(); });
  it('Collection detail', () => { renderAt('/finance/collections/r1', '/finance/collections/:id', <CollectionDetailPage />); expect(screen.getAllByText('Collection').length).toBeGreaterThan(0); });
  it('Lead detail', () => { renderAt('/admissions/leads/l1', '/admissions/leads/:id', <LeadDetailPage />); expect(screen.getAllByText('Lead').length).toBeGreaterThan(0); });
  it('Receipt detail', () => { renderAt('/parent/receipts/x1', '/parent/receipts/:id', <ReceiptDetailPage />); expect(screen.getAllByText('Receipt').length).toBeGreaterThan(0); });
  it('Conversation thread', () => { renderAt('/teacher/messages/t1', '/teacher/messages/:id', <TeacherConversationPage />); expect(screen.getByText('Conversation')).toBeInTheDocument(); });
});
