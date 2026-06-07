import '../../finance/finance_models.dart';
import '../../finance/widgets/finance_collection_trend_chart.dart';
import '../inventory_models.dart';

/// Maps inventory trend data to the shared finance trend chart widget.
class InventoryTrendChart extends FinanceCollectionTrendChart {
  InventoryTrendChart({
    super.key,
    required super.title,
    required List<InventoryTrendPoint> points,
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
