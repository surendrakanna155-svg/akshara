import { lazy, Suspense, type ComponentType } from 'react';

/**
 * Lazy chart boundary — recharts (~412 KB) is the single largest JS chunk and is
 * only used on dashboard pages. Loading it on demand keeps it out of the initial
 * bundle (perf certification finding). Pages import charts from here, not './Charts'.
 */
type SeriesCfg = { key: string; name: string };
export interface TrendProps {
  // Charting boundary: recharts types data as any[]; pages pass typed contract rows.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  data: any[];
  xKey: string;
  series: SeriesCfg[];
  height?: number;
  type?: 'line' | 'area';
}
export interface DonutProps {
  data: Array<{ name: string; value: number }>;
  height?: number;
}

const load = () => import('./Charts');
const LazyTrend = lazy(() => load().then((m) => ({ default: m.TrendChart as unknown as ComponentType<TrendProps> })));
const LazyBar = lazy(() => load().then((m) => ({ default: m.BarChartCard as unknown as ComponentType<TrendProps> })));
const LazyDonut = lazy(() => load().then((m) => ({ default: m.DonutChart as unknown as ComponentType<DonutProps> })));

function ChartSkeleton({ height = 260 }: { height?: number }) {
  return <div className="w-full animate-pulse rounded-md bg-surface-highest/60" style={{ height }} />;
}

export function TrendChart(props: TrendProps) {
  return (
    <Suspense fallback={<ChartSkeleton height={props.height} />}>
      <LazyTrend {...props} />
    </Suspense>
  );
}
export function BarChartCard(props: TrendProps) {
  return (
    <Suspense fallback={<ChartSkeleton height={props.height} />}>
      <LazyBar {...props} />
    </Suspense>
  );
}
export function DonutChart(props: DonutProps) {
  return (
    <Suspense fallback={<ChartSkeleton height={props.height} />}>
      <LazyDonut {...props} />
    </Suspense>
  );
}
