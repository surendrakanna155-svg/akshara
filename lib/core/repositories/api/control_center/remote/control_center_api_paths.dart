/// REST paths for the Control Center API module.
abstract final class ControlCenterApiPaths {
  static const String base = '/control-center';

  static const String dashboard = '$base/dashboard';

  /// GET lists platform schools; POST onboards a new school.
  static const String schools = '$base/schools';
  static const String subscriptions = '$base/subscriptions';
  static const String billing = '$base/billing';
  static const String crmPipeline = '$base/crm-pipeline';
  static const String supportTickets = '$base/support-tickets';
  static const String customerSuccess = '$base/customer-success';
  static const String whiteLabel = '$base/white-label';
  static const String analytics = '$base/analytics';
  static const String monitoring = '$base/monitoring';
  static const String roles = '$base/roles';
  static const String settings = '$base/settings';
  static const String providers = '$base/providers';
  static const String usage = '$base/usage';
  static const String features = '$base/features';

  /// PRC-A Batch 3 — AI credit wallet. NOT nested under [base]: the backend
  /// router mounts it at its own top-level prefix (`routeAiWallet`, prefix
  /// `/ai-wallet`) since it serves both the platform (grant) and org-level
  /// (view) audiences, not only the platform Control Center.
  static const String aiWallet = '/ai-wallet';
  static const String aiWalletGrant = '/ai-wallet/grant';

  /// PRC-A Batch 4 — storage quota. NOT nested under [base]: the backend
  /// router mounts it at its own top-level prefix (`routeStorageQuota`,
  /// prefix `/storage/quota`), mirroring [aiWallet].
  static const String storageQuota = '/storage/quota';
}
