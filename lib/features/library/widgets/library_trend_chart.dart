import '../../finance/finance_models.dart';
import '../../finance/widgets/finance_collection_trend_chart.dart';
import '../library_models.dart';

/// Maps library trend data to the shared finance trend chart widget.
class LibraryTrendChart extends FinanceCollectionTrendChart {
  LibraryTrendChart({
    super.key,
    required super.title,
    required List<LibraryTrendPoint> points,
    super.height,
  }) : super(
          points: [
            for (final p in points)
              CollectionTrendPoint(
                label: p.label,
                amountLakhs: p.amountLakhs,
                targetLakhs: p.targetLakhs,
              ),
          ],
        );
}
