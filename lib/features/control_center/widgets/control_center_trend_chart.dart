import '../../finance/finance_models.dart';
import '../../finance/widgets/finance_collection_trend_chart.dart';
import '../control_center_models.dart';

/// Maps control center trend data to the shared finance trend chart widget.
class ControlCenterTrendChart extends FinanceCollectionTrendChart {
  ControlCenterTrendChart({
    super.key,
    required super.title,
    required List<ControlCenterTrendPoint> points,
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
