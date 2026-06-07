import '../../finance/finance_models.dart';
import '../../finance/widgets/finance_collection_trend_chart.dart';
import '../hr_models.dart';

/// Maps HR trend data to the shared finance trend chart widget.
class HrTrendChart extends FinanceCollectionTrendChart {
  HrTrendChart({
    super.key,
    required super.title,
    required List<HrTrendPoint> points,
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
