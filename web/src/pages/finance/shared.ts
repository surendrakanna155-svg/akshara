import type { SemanticStatus } from '@/components/ui';
import type {
  CollectionStatus,
  DefaulterAgingBucket,
  DiscountApprovalStatus,
  FeeAccountStatus,
  RefundStatus,
} from '@/lib/contracts/finance';
import { MODULE_TABS } from '@/routes/navConfig';

export const FINANCE_TABS = MODULE_TABS.finance;

export const ACCOUNT_STATUS: Record<FeeAccountStatus, { status: SemanticStatus; label: string }> = {
  active: { status: 'success', label: 'Active' },
  overdue: { status: 'error', label: 'Overdue' },
  closed: { status: 'neutral', label: 'Closed' },
  pending: { status: 'warning', label: 'Pending' },
};

export const COLLECTION_STATUS: Record<CollectionStatus, { status: SemanticStatus; label: string }> = {
  completed: { status: 'success', label: 'Completed' },
  pending: { status: 'warning', label: 'Pending' },
  failed: { status: 'error', label: 'Failed' },
  refunded: { status: 'info', label: 'Refunded' },
};

export const AGING_BUCKET: Record<DefaulterAgingBucket, { status: SemanticStatus; label: string }> = {
  current: { status: 'success', label: 'Current' },
  days1to30: { status: 'info', label: '1–30 days' },
  days31to60: { status: 'warning', label: '31–60 days' },
  days61to90: { status: 'warning', label: '61–90 days' },
  over90: { status: 'error', label: '90+ days' },
};

export const REFUND_STATUS: Record<RefundStatus, { status: SemanticStatus; label: string }> = {
  pending: { status: 'warning', label: 'Pending' },
  approved: { status: 'info', label: 'Approved' },
  rejected: { status: 'error', label: 'Rejected' },
  processed: { status: 'success', label: 'Processed' },
};

export const DISCOUNT_STATUS: Record<DiscountApprovalStatus, { status: SemanticStatus; label: string }> = {
  pending: { status: 'warning', label: 'Pending' },
  approved: { status: 'success', label: 'Approved' },
  rejected: { status: 'error', label: 'Rejected' },
  active: { status: 'success', label: 'Active' },
};
