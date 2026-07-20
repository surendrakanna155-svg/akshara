import { createElement } from 'react';
import { cn } from '@/lib/utils/cn';

export type TextVariant =
  | 'display-lg'
  | 'display-md'
  | 'display-sm'
  | 'headline-md'
  | 'headline-sm'
  | 'title-lg'
  | 'title-md'
  | 'title-sm'
  | 'body-lg'
  | 'body-md'
  | 'body-sm'
  | 'label-lg'
  | 'label-md'
  | 'label-sm'
  | 'kpi-value'
  | 'kpi-label'
  | 'table-header'
  | 'table-cell'
  | 'mono';

const CLASS: Record<TextVariant, string> = {
  'display-lg': 'ak-display-lg',
  'display-md': 'ak-display-md',
  'display-sm': 'ak-display-sm',
  'headline-md': 'ak-headline-md',
  'headline-sm': 'ak-headline-sm',
  'title-lg': 'ak-title-lg',
  'title-md': 'ak-title-md',
  'title-sm': 'ak-title-sm',
  'body-lg': 'ak-body-lg',
  'body-md': 'ak-body-md',
  'body-sm': 'ak-body-sm',
  'label-lg': 'ak-label-lg',
  'label-md': 'ak-label-md',
  'label-sm': 'ak-label-sm',
  'kpi-value': 'ak-kpi-value',
  'kpi-label': 'ak-kpi-label',
  'table-header': 'ak-table-header',
  'table-cell': 'ak-table-cell',
  mono: 'ak-mono',
};

export interface TextProps extends React.HTMLAttributes<HTMLElement> {
  variant?: TextVariant;
  as?: keyof JSX.IntrinsicElements;
  tabular?: boolean;
}

/** Typographic primitive bound to the M15 type ramp. */
export function Text({ variant = 'body-md', as = 'p', tabular, className, children, ...rest }: TextProps) {
  return createElement(
    as,
    { className: cn(CLASS[variant], tabular && 'ak-tabular', className), ...rest },
    children,
  );
}
