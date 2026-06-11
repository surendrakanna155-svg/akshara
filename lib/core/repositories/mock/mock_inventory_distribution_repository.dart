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

  @override
  Future<InvDistributionDashboard> getDashboard({required RepositoryQuery query}) async {
    return InvDistributionDashboard(
      pendingDistributions: _items.where((i) => i.status == 'available').length,
      replacementRequests: 0,
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
    final dist = await transitionStatus(
      query: query,
      distributionId: distributionId,
      status: 'replacement_requested',
      notes: notes,
    );
    return (distribution: dist, paymentRequestId: null);
  }

  @override
  Future<InvDistributionReports> getReports({required RepositoryQuery query}) async {
    return const InvDistributionReports(
      pending: 1,
      issued: 1,
      replacement: 0,
      lost: 0,
      damaged: 0,
      byKitCategory: [
        InvKitCategoryReport(category: 'books', pending: 0, issued: 1),
        InvKitCategoryReport(category: 'uniforms', pending: 1, issued: 0),
      ],
    );
  }
}
