import { useEffect, useState } from 'react';
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Line,
  LineChart,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { chartPalette, cssVarColor } from '@/theme/tokens';
import { useTheme } from '@/theme/ThemeProvider';

/** Re-reads themed chart colors whenever light/dark flips. */
function usePalette() {
  const { resolved } = useTheme();
  const [pal, setPal] = useState<string[]>(() => chartPalette());
  const [grid, setGrid] = useState<string>(() => cssVarColor('--ak-chart-grid'));
  useEffect(() => {
    setPal(chartPalette());
    setGrid(cssVarColor('--ak-chart-grid'));
  }, [resolved]);
  return { pal, grid };
}

const axisStyle = { fontSize: 12, fontFamily: 'Roboto' };

function ChartTooltip({ active, payload, label }: { active?: boolean; payload?: { name: string; value: number; color: string }[]; label?: string }) {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-md border border-outline-variant bg-surface px-s3 py-s2 shadow-ak-3">
      {label && <div className="ak-label-md mb-s1 text-on-surface">{label}</div>}
      {payload.map((p) => (
        <div key={p.name} className="flex items-center gap-s2 ak-body-sm text-on-surface-variant">
          <span className="h-2 w-2 rounded-full" style={{ background: p.color }} />
          <span>{p.name}</span>
          <span className="ml-auto font-semibold text-on-surface">{p.value.toLocaleString('en-IN')}</span>
        </div>
      ))}
    </div>
  );
}

export interface TrendChartProps<T extends object> {
  data: T[];
  xKey: keyof T & string;
  series: { key: keyof T & string; name: string }[];
  height?: number;
  type?: 'line' | 'area';
}

export function TrendChart<T extends object>({ data, xKey, series, height = 260, type = 'area' }: TrendChartProps<T>) {
  const { pal, grid } = usePalette();
  const on = cssVarColor('--ak-on-surface-variant');
  return (
    <ResponsiveContainer width="100%" height={height}>
      {type === 'area' ? (
        <AreaChart data={data} margin={{ top: 8, right: 8, bottom: 0, left: -12 }}>
          <defs>
            {series.map((s, i) => (
              <linearGradient key={s.key} id={`g-${s.key}`} x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor={pal[i % pal.length]} stopOpacity={0.28} />
                <stop offset="100%" stopColor={pal[i % pal.length]} stopOpacity={0.02} />
              </linearGradient>
            ))}
          </defs>
          <CartesianGrid stroke={grid} vertical={false} />
          <XAxis dataKey={xKey} tick={{ ...axisStyle, fill: on }} axisLine={false} tickLine={false} />
          <YAxis tick={{ ...axisStyle, fill: on }} axisLine={false} tickLine={false} width={48} />
          <Tooltip content={<ChartTooltip />} />
          {series.map((s, i) => (
            <Area
              key={s.key}
              type="monotone"
              dataKey={s.key}
              name={s.name}
              stroke={pal[i % pal.length]}
              strokeWidth={2.5}
              fill={`url(#g-${s.key})`}
            />
          ))}
        </AreaChart>
      ) : (
        <LineChart data={data} margin={{ top: 8, right: 8, bottom: 0, left: -12 }}>
          <CartesianGrid stroke={grid} vertical={false} />
          <XAxis dataKey={xKey} tick={{ ...axisStyle, fill: on }} axisLine={false} tickLine={false} />
          <YAxis tick={{ ...axisStyle, fill: on }} axisLine={false} tickLine={false} width={48} />
          <Tooltip content={<ChartTooltip />} />
          {series.map((s, i) => (
            <Line key={s.key} type="monotone" dataKey={s.key} name={s.name} stroke={pal[i % pal.length]} strokeWidth={2.5} dot={false} />
          ))}
        </LineChart>
      )}
    </ResponsiveContainer>
  );
}

export function BarChartCard<T extends object>({ data, xKey, series, height = 260 }: TrendChartProps<T>) {
  const { pal, grid } = usePalette();
  const on = cssVarColor('--ak-on-surface-variant');
  return (
    <ResponsiveContainer width="100%" height={height}>
      <BarChart data={data} margin={{ top: 8, right: 8, bottom: 0, left: -12 }}>
        <CartesianGrid stroke={grid} vertical={false} />
        <XAxis dataKey={xKey} tick={{ ...axisStyle, fill: on }} axisLine={false} tickLine={false} />
        <YAxis tick={{ ...axisStyle, fill: on }} axisLine={false} tickLine={false} width={48} />
        <Tooltip content={<ChartTooltip />} cursor={{ fill: 'rgb(var(--ak-surface-highest) / 0.5)' }} />
        {series.map((s, i) => (
          <Bar key={s.key} dataKey={s.key} name={s.name} fill={pal[i % pal.length]} radius={[6, 6, 0, 0]} maxBarSize={44} />
        ))}
      </BarChart>
    </ResponsiveContainer>
  );
}

export interface DonutDatum {
  name: string;
  value: number;
}

export function DonutChart({ data, height = 240 }: { data: DonutDatum[]; height?: number }) {
  const { pal } = usePalette();
  return (
    <ResponsiveContainer width="100%" height={height}>
      <PieChart>
        <Pie data={data} dataKey="value" nameKey="name" innerRadius="58%" outerRadius="86%" paddingAngle={2} stroke="none">
          {data.map((_, i) => (
            <Cell key={i} fill={pal[i % pal.length]} />
          ))}
        </Pie>
        <Tooltip content={<ChartTooltip />} />
      </PieChart>
    </ResponsiveContainer>
  );
}
