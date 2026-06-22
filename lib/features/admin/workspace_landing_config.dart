import '../../core/workspace/workspace.dart';
import '../../shared/widgets/premium/akshara_line_art.dart';
import '../../shared/widgets/premium/akshara_workspace_landing.dart';

/// Presentation config for the branded [AksharaWorkspaceLanding] hero on the
/// admin hub — the motif and headline stats that give each workspace its own
/// "you are here" personality above the module grid.
///
/// Stats are curated demo figures consistent with the seeded school so demos
/// read as live. Swap to real per-workspace summary providers when those
/// endpoints exist; the hero widget already accepts any [AksharaWorkspaceStat]
/// list, so no UI change is needed then.
class WorkspaceLandingConfig {
  const WorkspaceLandingConfig({
    required this.motif,
    this.eyebrow = 'WORKSPACE',
    this.stats = const <AksharaWorkspaceStat>[],
  });

  final AksharaMotif motif;
  final String eyebrow;
  final List<AksharaWorkspaceStat> stats;
}

/// Hero config per staff workspace that lands on the admin hub. Workspaces
/// without an entry fall back to a name-only hero (see `AdminHubScreen`).
const Map<WorkspaceId, WorkspaceLandingConfig> kWorkspaceLandingConfig = {
  WorkspaceId.schoolAdministration: WorkspaceLandingConfig(
    motif: AksharaMotif.graduationCap,
    stats: [
      AksharaWorkspaceStat(value: '1,248', label: 'Students'),
      AksharaWorkspaceStat(value: '86', label: 'Staff'),
      AksharaWorkspaceStat(value: '96%', label: 'Attendance'),
    ],
  ),
  WorkspaceId.finance: WorkspaceLandingConfig(
    motif: AksharaMotif.chart,
    stats: [
      AksharaWorkspaceStat(value: '₹4.2L', label: 'Collected today'),
      AksharaWorkspaceStat(value: '₹1.8L', label: 'Pending'),
      AksharaWorkspaceStat(value: '92%', label: 'This month'),
    ],
  ),
  WorkspaceId.frontOffice: WorkspaceLandingConfig(
    motif: AksharaMotif.message,
    stats: [
      AksharaWorkspaceStat(value: '23', label: 'Open enquiries'),
      AksharaWorkspaceStat(value: '14', label: 'Admissions'),
      AksharaWorkspaceStat(value: '9', label: 'Visitors today'),
    ],
  ),
  WorkspaceId.inventory: WorkspaceLandingConfig(
    motif: AksharaMotif.chart,
    stats: [
      AksharaWorkspaceStat(value: '642', label: 'SKUs'),
      AksharaWorkspaceStat(value: '12', label: 'Low stock'),
      AksharaWorkspaceStat(value: '38', label: 'Issued today'),
    ],
  ),
  WorkspaceId.transport: WorkspaceLandingConfig(
    motif: AksharaMotif.bus,
    stats: [
      AksharaWorkspaceStat(value: '18', label: 'Routes'),
      AksharaWorkspaceStat(value: '22', label: 'Buses'),
      AksharaWorkspaceStat(value: '97%', label: 'On-time'),
    ],
  ),
  WorkspaceId.hostel: WorkspaceLandingConfig(
    motif: AksharaMotif.campus,
    stats: [
      AksharaWorkspaceStat(value: '312', label: 'Residents'),
      AksharaWorkspaceStat(value: '96', label: 'Rooms'),
      AksharaWorkspaceStat(value: '88%', label: 'Occupancy'),
    ],
  ),
  WorkspaceId.library: WorkspaceLandingConfig(
    motif: AksharaMotif.bookshelf,
    stats: [
      AksharaWorkspaceStat(value: '8,450', label: 'Titles'),
      AksharaWorkspaceStat(value: '214', label: 'On loan'),
      AksharaWorkspaceStat(value: '7', label: 'Overdue'),
    ],
  ),
};
