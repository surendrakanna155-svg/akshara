/// Operational metrics tracked by the client observability layer.
class OperationalMetricDescriptor {
  const OperationalMetricDescriptor({
    required this.id,
    required this.category,
    required this.description,
  });

  final String id;
  final String category;
  final String description;
}

const List<OperationalMetricDescriptor> kOperationalMetrics = [
  OperationalMetricDescriptor(
    id: 'api.request.duration_ms',
    category: 'network',
    description: 'HTTP request round-trip latency',
  ),
  OperationalMetricDescriptor(
    id: 'api.request.error_count',
    category: 'network',
    description: 'Failed API responses by status code',
  ),
  OperationalMetricDescriptor(
    id: 'auth.session.refresh_count',
    category: 'auth',
    description: 'Token refresh attempts',
  ),
  OperationalMetricDescriptor(
    id: 'audit.queue.pending_count',
    category: 'compliance',
    description: 'Audit events awaiting upload',
  ),
  OperationalMetricDescriptor(
    id: 'audit.queue.failed_count',
    category: 'compliance',
    description: 'Audit upload failures',
  ),
  OperationalMetricDescriptor(
    id: 'mobile.mutation.success_count',
    category: 'mobile',
    description: 'Successful mobile write mutations',
  ),
  OperationalMetricDescriptor(
    id: 'mobile.mutation.error_count',
    category: 'mobile',
    description: 'Failed mobile write mutations',
  ),
  OperationalMetricDescriptor(
    id: 'erp.pagination.page_fetch_ms',
    category: 'performance',
    description: 'Paginated list fetch duration',
  ),
];

int get operationalMetricCount => kOperationalMetrics.length;
