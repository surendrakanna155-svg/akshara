import type { SemanticStatus } from '@/components/ui';
import type { LibraryBookStatus, LibraryFineStatus, LibraryLoanStatus, LibraryMemberStatus } from '@/lib/contracts/library';
import { MODULE_TABS } from '@/routes/navConfig';

export const LIBRARY_TABS = MODULE_TABS.library;

export const BOOK_STATUS: Record<LibraryBookStatus, { status: SemanticStatus; label: string }> = {
  available: { status: 'success', label: 'Available' },
  issued: { status: 'info', label: 'Issued' },
  reserved: { status: 'pending', label: 'Reserved' },
  damaged: { status: 'error', label: 'Damaged' },
};

export const MEMBER_STATUS: Record<LibraryMemberStatus, { status: SemanticStatus; label: string }> = {
  active: { status: 'success', label: 'Active' },
  blocked: { status: 'error', label: 'Blocked' },
  expired: { status: 'neutral', label: 'Expired' },
};

export const LOAN_STATUS: Record<LibraryLoanStatus, { status: SemanticStatus; label: string }> = {
  active: { status: 'info', label: 'Active' },
  overdue: { status: 'error', label: 'Overdue' },
  returned: { status: 'success', label: 'Returned' },
};

export const FINE_STATUS: Record<LibraryFineStatus, { status: SemanticStatus; label: string }> = {
  pending: { status: 'warning', label: 'Pending' },
  paid: { status: 'success', label: 'Paid' },
  waived: { status: 'neutral', label: 'Waived' },
};
