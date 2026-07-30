import '../../core/workspace/workspace.dart';
import '../../shared/widgets/premium/akshara_line_art.dart';
import '../../shared/widgets/premium/akshara_workspace_landing.dart';

/// Presentation config for the branded [AksharaWorkspaceLanding] hero on the
/// admin hub — the motif and headline that give each workspace its own
/// "you are here" personality above the module grid.
///
/// JOURNEY-001 (P0): this file used to carry a `stats` table of *curated demo
/// figures* — "1,248 Students · 96% Attendance", "₹4.2L Collected today" —
/// which the hub rendered as live KPIs to 6 of 15 staff roles, on day one, on a
/// brand-new tenant with no students and no collections. Nothing in the UI
/// marked them as demo data.
///
/// The stats are gone and MUST NOT be replaced with another constant. The hero
/// is name-only until real per-workspace summary providers exist; when they do,
/// they feed [AksharaWorkspaceStat] values from the server at the call site.
/// The guard test asserts this file declares zero stats.
class WorkspaceLandingConfig {
  const WorkspaceLandingConfig({
    required this.motif,
    this.eyebrow = 'WORKSPACE',
  });

  final AksharaMotif motif;
  final String eyebrow;
}

/// Hero config per staff workspace that lands on the admin hub. Workspaces
/// without an entry fall back to a name-only hero (see `AdminHubScreen`).
const Map<WorkspaceId, WorkspaceLandingConfig> kWorkspaceLandingConfig = {
  WorkspaceId.schoolAdministration: WorkspaceLandingConfig(
    motif: AksharaMotif.graduationCap,
  ),
  WorkspaceId.finance: WorkspaceLandingConfig(
    motif: AksharaMotif.chart,
  ),
  WorkspaceId.frontOffice: WorkspaceLandingConfig(
    motif: AksharaMotif.message,
  ),
  WorkspaceId.inventory: WorkspaceLandingConfig(
    motif: AksharaMotif.chart,
  ),
  WorkspaceId.transport: WorkspaceLandingConfig(
    motif: AksharaMotif.bus,
  ),
  WorkspaceId.hostel: WorkspaceLandingConfig(
    motif: AksharaMotif.campus,
  ),
  WorkspaceId.library: WorkspaceLandingConfig(
    motif: AksharaMotif.bookshelf,
  ),
};
