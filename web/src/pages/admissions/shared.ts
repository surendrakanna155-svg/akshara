import type { SemanticStatus } from '@/components/ui';
import type { ApplicationStatus, DocumentVerificationStatus } from '@/lib/contracts/admissions';
import { MODULE_TABS } from '@/routes/navConfig';

export const ADMISSIONS_TABS = MODULE_TABS.admissions;

export const APPLICATION_STATUS: Record<ApplicationStatus, { status: SemanticStatus; label: string }> = {
  draft: { status: 'neutral', label: 'Draft' },
  submitted: { status: 'info', label: 'Submitted' },
  documentsPending: { status: 'warning', label: 'Documents pending' },
  underReview: { status: 'pending', label: 'Under review' },
  approved: { status: 'success', label: 'Approved' },
  rejected: { status: 'error', label: 'Rejected' },
};

export const DOC_STATUS: Record<DocumentVerificationStatus, { status: SemanticStatus; label: string }> = {
  missing: { status: 'warning', label: 'Missing' },
  uploaded: { status: 'info', label: 'Uploaded' },
  verified: { status: 'success', label: 'Verified' },
  rejected: { status: 'error', label: 'Rejected' },
};
