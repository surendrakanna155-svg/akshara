import '../../finance/finance_models.dart';
import '../../finance/widgets/finance_collection_trend_chart.dart';
import '../alumni_models.dart';

/// Maps alumni trend data to the shared finance trend chart widget.
class AlumniTrendChart extends FinanceCollectionTrendChart {
  AlumniTrendChart({
    super.key,
    required super.title,
    required List<AlumniTrendPoint> points,
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
