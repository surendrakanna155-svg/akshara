/// Phase 5 routes that must be registered in server RBAC inventory and deployed to staging.
abstract final class Phase5StagingRouteManifest {
  static const routes = [
    ('GET', '/parent/experience/hub'),
    ('POST', '/parent/experience/acknowledge'),
    ('GET', '/employees/intelligence/dashboard'),
    ('GET', '/employees/:id/360'),
    ('GET', '/operations/hub'),
    ('GET', '/memories/events'),
    ('GET', '/memories/analytics'),
    ('GET', '/memories/events/:id'),
    ('POST', '/memories/events/:id/upload/presign'),
    ('POST', '/memories/events/:id/upload/confirm'),
    ('GET', '/memories/media/:id/download'),
    ('GET', '/memories/share/:token'),
    ('GET', '/promotions'),
    ('POST', '/promotions/:id/generate'),
    ('POST', '/promotions/:id/approve'),
    ('POST', '/promotions/:id/publish'),
    ('POST', '/promotions/:id/track'),
    ('GET', '/inventory/distribution/reports'),
  ];
}
