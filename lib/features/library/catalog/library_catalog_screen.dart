import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/security/permissions.dart';
import '../../../core/testing/qa_test_keys.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../library_models.dart';
import '../library_providers.dart';
import '../library_workflow_actions.dart';
import '../widgets/library_kpi_row.dart';
import '../widgets/library_module_scaffold.dart';

/// LB-02 — Book Catalog.
class LibraryCatalogScreen extends ConsumerWidget {
  const LibraryCatalogScreen({super.key});

  static const List<String> filterLabels = [
    'All',
    'Available',
    'Issued',
    'Textbooks',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(libraryCatalogLoadingProvider);
    final isError = ref.watch(libraryCatalogErrorProvider);
    final isEmpty = ref.watch(libraryCatalogEmptyProvider);
    final books = ref.watch(libraryFilteredCatalogProvider);
    final filterIndex = ref.watch(libraryCatalogFilterProvider);
    final pageResult = ref.watch(libraryCatalogPageResultProvider);

    return LibraryModuleScaffold(
      screen: LibraryScreen.catalog,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(libraryCatalogFilterProvider.notifier).state = index,
      filterTrailing: AksharaManageAction(
        permission: Permission.manageLibrary,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: QaTestKeys.libraryImportBooksButton,
              onPressed: () => showImportLibraryBooksSheet(context, ref),
              icon: const Icon(Icons.upload_file_outlined),
              tooltip: 'Import books (CSV)',
            ),
            const SizedBox(width: AksharaSpacing.s2),
            FilledButton.icon(
              key: QaTestKeys.libraryAddBookButton,
              onPressed: () => showAddLibraryBookDialog(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add book'),
            ),
          ],
        ),
      ),
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        isEmpty: isEmpty,
        books: books,
        pageResult: pageResult,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required bool isEmpty,
    required List<LibraryBook> books,
    required PaginatedResult<LibraryBook>? pageResult,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading book catalog'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load book catalog.',
      );
    }

    if (isEmpty || books.isEmpty) {
      return const AksharaEmptyState(
        message: 'No books match the selected filters.',
        icon: Icons.menu_book_outlined,
      );
    }

    final available = books.where((b) => b.availableCopies > 0).length;
    final totalCopies = books.fold<int>(0, (sum, b) => sum + b.totalCopies);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LibraryKpiRow(
          kpis: [
            LibraryKpi(
              id: 'titles',
              value: '${books.length}',
              label: 'Titles',
              icon: Icons.library_books_outlined,
              accentName: 'primary',
            ),
            LibraryKpi(
              id: 'copies',
              value: '$totalCopies',
              label: 'Total copies',
              icon: Icons.copy_all_outlined,
              accentName: 'neutral',
            ),
            LibraryKpi(
              id: 'available',
              value: '$available',
              label: 'Available titles',
              icon: Icons.check_circle_outline,
              accentName: 'success',
            ),
          ],
          desktopColumns: 3,
        ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Book catalog'),
        const SizedBox(height: AksharaSpacing.s3),
        _CatalogTable(books: books),
        AksharaPaginatedListFooter<LibraryBook>(
          result: pageResult,
          pageProvider: libraryCatalogPageProvider,
        ),
      ],
    );
  }
}

class _CatalogTable extends StatelessWidget {
  const _CatalogTable({required this.books});

  final List<LibraryBook> books;

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final book in books) ...[
            _BookCard(book: book),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return Semantics(
      container: true,
      label: 'Book catalog table, ${books.length} titles',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            columns: const [
              DataColumn(label: Text('ISBN')),
              DataColumn(label: Text('Title')),
              DataColumn(label: Text('Author')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Copies')),
              DataColumn(label: Text('Available')),
              DataColumn(label: Text('Shelf')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final book in books)
                DataRow(
                  cells: [
                    DataCell(Text(book.isbn)),
                    DataCell(Text(book.title)),
                    DataCell(Text(book.author)),
                    DataCell(Text(book.category)),
                    DataCell(Text('${book.totalCopies}')),
                    DataCell(Text('${book.availableCopies}')),
                    DataCell(Text(book.shelf)),
                    DataCell(_BookStatusChip(status: book.status)),
                    DataCell(_BookActions(book: book)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// LIB-2 — per-book Edit / Delete actions, manageLibrary-gated.
class _BookActions extends StatelessWidget {
  const _BookActions({required this.book});

  final LibraryBook book;

  @override
  Widget build(BuildContext context) {
    return AksharaManageAction(
      permission: Permission.manageLibrary,
      child: Consumer(
        builder: (context, ref, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: QaTestKeys.libraryEditBookButton(book.id),
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit book',
              onPressed: () => showEditLibraryBookDialog(context, ref, book),
            ),
            IconButton(
              key: QaTestKeys.libraryDeleteBookButton(book.id),
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Delete book',
              onPressed: () => deleteLibraryBook(context, ref, book),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book});

  final LibraryBook book;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Semantics(
      label: '${book.title} by ${book.author}, shelf ${book.shelf}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(book.title, style: text.titleSmall),
              Text(book.author, style: text.bodyMedium),
              Text(
                '${book.availableCopies}/${book.totalCopies} available · ${book.shelf}',
                style: text.bodySmall,
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _BookStatusChip(status: book.status),
                  _BookActions(book: book),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookStatusChip extends StatelessWidget {
  const _BookStatusChip({required this.status});

  final LibraryBookStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      LibraryBookStatus.available => ('Available', KpiAccent.success),
      LibraryBookStatus.issued => ('Issued', KpiAccent.primary),
      LibraryBookStatus.reserved => ('Reserved', KpiAccent.warning),
      LibraryBookStatus.damaged => ('Damaged', KpiAccent.error),
      LibraryBookStatus.lost => ('Lost', KpiAccent.error),
    };

    return AksharaStatusChip(
      label: label,
      tone: tone,
      semanticLabel: 'Book status: $label',
    );
  }
}
