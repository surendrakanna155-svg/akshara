import '../../finance/finance_models.dart';
import '../../finance/widgets/finance_collection_trend_chart.dart';
import '../management_models.dart';

/// Maps management trend data to the shared finance trend chart widget.
class ManagementTrendChart extends FinanceCollectionTrendChart {
  ManagementTrendChart({
    super.key,
    required super.title,
    required List<ManagementTrendPoint> points,
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
