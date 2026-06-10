import '../../../../features/finance/finance_models.dart';

/// Client-side installment plan options for fee assignment UI.
///
/// Backend invoices are annual (4B3A); additional plans are offered for UI
/// parity until multi-term billing is implemented server-side.
const List<InstallmentPlan> kFinanceInstallmentPlanCatalog = [
  InstallmentPlan(
    id: 'plan_annual',
    label: 'Annual single payment',
    installmentCount: 1,
    type: InstallmentPlanType.annual,
  ),
  InstallmentPlan(
    id: 'plan_quarterly',
    label: '3-term quarterly',
    installmentCount: 3,
    type: InstallmentPlanType.quarterly,
  ),
  InstallmentPlan(
    id: 'plan_termly',
    label: '4-term termly',
    installmentCount: 4,
    type: InstallmentPlanType.termly,
  ),
  InstallmentPlan(
    id: 'plan_monthly',
    label: '10-month monthly',
    installmentCount: 10,
    type: InstallmentPlanType.monthly,
  ),
];
