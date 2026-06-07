import '../../finance/finance_models.dart';
import '../../finance/widgets/finance_collection_trend_chart.dart';
import '../transport_models.dart';

/// Maps transport trend data to the shared finance trend chart widget.
class TransportTrendChart extends FinanceCollectionTrendChart {
  TransportTrendChart({
    super.key,
    required super.title,
    required List<TransportTrendPoint> points,
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
