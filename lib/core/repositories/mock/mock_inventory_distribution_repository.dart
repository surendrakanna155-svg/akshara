import '../../../features/inventory_distribution/inventory_distribution_models.dart';
import '../../../features/phase5/phase5_models.dart';
import '../interfaces/inventory_distribution_repository.dart';
import '../repository_query.dart';

class MockInventoryDistributionRepository implements InventoryDistributionRepository {
  final List<InvStudentDistribution> _items = [
    const InvStudentDistribution(
      id: 'dist_1',
      studentId: 'student_1',
      catalogItemId: 'cat_1',
      itemName: 'Mathematics Textbook Grade 8',
      category: 'books',
      quantity: 1,
      status: 'distributed',
    ),
    const InvStudentDistribution(
      id: 'dist_2',
      studentId: 'student_2',
      catalogItemId: 'cat_2',
      itemName: 'School Uniform Set',
      category: 'uniforms',
      quantity: 1,
      status: 'available',
    ),
  ];

  final List<InvReplacementRequest> _replacementRequests = [
    const InvReplacementRequest(
      id: 'rpl_1',
      distributionId: 'dist_1',
      studentId: 'student_1',
      itemName: 'Mathematics Textbook Grade 8',
      category: 'books',
      quantity: 1,
      status: 'pending',
      notes: 'Pages torn — needs replacement',
      requestedAt: '2026-06-01T10:00:00Z',
    ),
  ];

  int get _openReplacementCount =>
      _replacementRequests.where((r) => r.status == 'pending' || r.status == 'approved').length;

  @override
  Future<InvDistributionDashboard> getDashboard({required RepositoryQuery query}) async {
    return InvDistributionDashboard(
      pendingDistributions: _items.where((i) => i.status == 'available').length,
      replacementRequests: _openReplacementCount,
      paymentPending: 0,
      distributedToday: 1,
      byCategory: const [
        {'category': 'books', 'count': 1},
        {'category': 'uniforms', 'count': 1},
      ],
    );
  }

  @override
  Future<List<InvCatalogItem>> listCatalog({
    required RepositoryQuery query,
    String? category,
  }) async {
    return const [
      InvCatalogItem(
        id: 'cat_1',
        category: 'books',
        name: 'Mathematics Textbook Grade 8',
        skuCode: 'BK-MATH-8',
        unitPrice: 45000,
        stockOnHand: 120,
      ),
      InvCatalogItem(
        id: 'cat_2',
        category: 'uniforms',
        name: 'School Uniform Set',
        skuCode: 'UNI-SET',
        unitPrice: 120000,
        stockOnHand: 80,
      ),
    ];
  }

  @override
  Future<List<InvStudentDistribution>> listDistributions({
    required RepositoryQuery query,
    String? studentId,
    String? status,
  }) async {
    return _items.where((i) {
      if (studentId != null && i.studentId != studentId) return false;
      if (status != null && i.status != status) return false;
      return true;
    }).toList();
  }

  @override
  Future<InvStudentDistribution> createDistribution({
    required RepositoryQuery query,
    required String studentId,
    required String catalogItemId,
    int quantity = 1,
  }) async {
    final created = InvStudentDistribution(
      id: 'dist_new',
      studentId: studentId,
      catalogItemId: catalogItemId,
      itemName: 'Distributed item',
      category: 'books',
      quantity: quantity,
      status: 'available',
    );
    _items.add(created);
    return created;
  }

  @override
  Future<InvStudentDistribution> transitionStatus({
    required RepositoryQuery query,
    required String distributionId,
    required String status,
    String? notes,
  }) async {
    final idx = _items.indexWhere((i) => i.id == distributionId);
    if (idx < 0) throw StateError('Distribution not found');
    final updated = InvStudentDistribution(
      id: _items[idx].id,
      studentId: _items[idx].studentId,
      catalogItemId: _items[idx].catalogItemId,
      itemName: _items[idx].itemName,
      category: _items[idx].category,
      quantity: _items[idx].quantity,
      status: status,
      distributedAt: status == 'distributed' ? DateTime.now().toIso8601String() : null,
      acknowledgedAt: status == 'parent_acknowledged' ? DateTime.now().toIso8601String() : null,
      paymentRequestId: _items[idx].paymentRequestId,
    );
    _items[idx] = updated;
    return updated;
  }

  @override
  Future<({InvStudentDistribution distribution, String? paymentRequestId})> requestReplacement({
    required RepositoryQuery query,
    required String distributionId,
    String? notes,
  }) async {
    final idx = _items.indexWhere((i) => i.id == distributionId);
    if (idx < 0) throw StateError('Distribution not found');
    final source = _items[idx];
    final dist = await transitionStatus(
      query: query,
      distributionId: distributionId,
      status: 'replacement_requested',
      notes: notes,
    );
    _replacementRequests.add(
      InvReplacementRequest(
        id: 'rpl_${_replacementRequests.length + 1}',
        distributionId: distributionId,
        studentId: source.studentId,
        itemName: source.itemName,
        category: source.category,
        quantity: source.quantity,
        status: 'pending',
        notes: notes,
        requestedAt: DateTime.now().toIso8601String(),
      ),
    );
    return (distribution: dist, paymentRequestId: null);
  }

  @override
  Future<List<InvReplacementRequest>> listReplacementRequests({
    required RepositoryQuery query,
    String? status,
  }) async {
    return _replacementRequests.where((r) {
      if (status != null && r.status != status) return false;
      return true;
    }).toList();
  }

  @override
  Future<InvReplacementRequest> approveReplacement({
    required RepositoryQuery query,
    required String requestId,
  }) async {
    return _updateReplacement(requestId, (r) => InvReplacementRequest(
          id: r.id,
          distributionId: r.distributionId,
          studentId: r.studentId,
          itemName: r.itemName,
          category: r.category,
          quantity: r.quantity,
          status: 'approved',
          notes: r.notes,
          requestedAt: r.requestedAt,
          resolvedAt: DateTime.now().toIso8601String(),
          rejectionReason: r.rejectionReason,
        ));
  }

  @override
  Future<InvReplacementRequest> fulfillReplacement({
    required RepositoryQuery query,
    required String requestId,
  }) async {
    final request = _replacementRequests.firstWhere((r) => r.id == requestId);
    await createDistribution(
      query: query,
      studentId: request.studentId,
      catalogItemId: _items
              .firstWhere((i) => i.id == request.distributionId,
                  orElse: () => _items.first)
              .catalogItemId,
      quantity: request.quantity,
    );
    return _updateReplacement(requestId, (r) => InvReplacementRequest(
          id: r.id,
          distributionId: r.distributionId,
          studentId: r.studentId,
          itemName: r.itemName,
          category: r.category,
          quantity: r.quantity,
          status: 'fulfilled',
          notes: r.notes,
          requestedAt: r.requestedAt,
          resolvedAt: DateTime.now().toIso8601String(),
          rejectionReason: r.rejectionReason,
        ));
  }

  @override
  Future<InvReplacementRequest> rejectReplacement({
    required RepositoryQuery query,
    required String requestId,
    String? reason,
  }) async {
    return _updateReplacement(requestId, (r) => InvReplacementRequest(
          id: r.id,
          distributionId: r.distributionId,
          studentId: r.studentId,
          itemName: r.itemName,
          category: r.category,
          quantity: r.quantity,
          status: 'rejected',
          notes: r.notes,
          requestedAt: r.requestedAt,
          resolvedAt: DateTime.now().toIso8601String(),
          rejectionReason: reason,
        ));
  }

  InvReplacementRequest _updateReplacement(
    String requestId,
    InvReplacementRequest Function(InvReplacementRequest current) transform,
  ) {
    final idx = _replacementRequests.indexWhere((r) => r.id == requestId);
    if (idx < 0) throw StateError('Replacement request not found');
    final updated = transform(_replacementRequests[idx]);
    _replacementRequests[idx] = updated;
    return updated;
  }

  @override
  Future<InvDistributionReports> getReports({required RepositoryQuery query}) async {
    return InvDistributionReports(
      pending: 1,
      issued: 1,
      replacement: _replacementRequests.where((r) => r.status == 'pending').length,
      lost: 0,
      damaged: 0,
      byKitCategory: const [
        InvKitCategoryReport(category: 'books', pending: 0, issued: 1),
        InvKitCategoryReport(category: 'uniforms', pending: 1, issued: 0),
      ],
    );
  }
}
