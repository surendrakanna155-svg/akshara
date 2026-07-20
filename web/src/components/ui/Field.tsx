import { forwardRef, useId } from 'react';
import { cn } from '@/lib/utils/cn';
import { Icon } from '@/components/Icon';

// Ports lib/theme/app_theme.dart _inputDecorationTheme — filled, 8px radius,
// surfaceContainerLow fill, 2px primary focus ring, error states.
const fieldBase =
  'w-full rounded-sm border bg-surface-low text-on-surface placeholder:text-on-surface-variant/80 ' +
  'transition-colors duration-fast outline-none ak-body-md ' +
  'disabled:cursor-not-allowed disabled:opacity-60';

function borderFor(error?: boolean) {
  return error
    ? 'border-error focus:border-error focus:ring-2 focus:ring-error/30'
    : 'border-outline-variant/75 focus:border-primary focus:ring-2 focus:ring-primary/25';
}

export interface LabelProps {
  label?: string;
  htmlFor?: string;
  required?: boolean;
  hint?: string;
  error?: string;
  children: React.ReactNode;
  className?: string;
}

export function Field({ label, htmlFor, required, hint, error, children, className }: LabelProps) {
  return (
    <div className={cn('flex flex-col gap-s1', className)}>
      {label && (
        <label htmlFor={htmlFor} className="ak-label-md text-on-surface-variant">
          {label}
          {required && <span className="text-error"> *</span>}
        </label>
      )}
      {children}
      {error ? (
        <span className="ak-body-sm text-error">{error}</span>
      ) : (
        hint && <span className="ak-body-sm text-on-surface-variant">{hint}</span>
      )}
    </div>
  );
}

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  hint?: string;
  error?: string;
  leadingIcon?: string;
  trailingIcon?: string;
  onTrailingClick?: () => void;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(function Input(
  { label, hint, error, leadingIcon, trailingIcon, onTrailingClick, className, id, ...rest },
  ref,
) {
  const gid = useId();
  const fid = id || gid;
  const field = (
    <div className="relative">
      {leadingIcon && (
        <Icon
          name={leadingIcon}
          size={20}
          className="pointer-events-none absolute left-s3 top-1/2 -translate-y-1/2 text-on-surface-variant"
        />
      )}
      <input
        ref={ref}
        id={fid}
        className={cn(fieldBase, borderFor(!!error), 'h-11', leadingIcon ? 'pl-s10' : 'pl-s4', trailingIcon ? 'pr-s10' : 'pr-s4', className)}
        {...rest}
      />
      {trailingIcon && (
        <button
          type="button"
          tabIndex={onTrailingClick ? 0 : -1}
          onClick={onTrailingClick}
          className="absolute right-s2 top-1/2 grid h-8 w-8 -translate-y-1/2 place-items-center rounded-full text-on-surface-variant hover:bg-on-surface/5"
        >
          <Icon name={trailingIcon} size={20} />
        </button>
      )}
    </div>
  );
  if (!label && !hint && !error) return field;
  return (
    <Field label={label} htmlFor={fid} hint={hint} error={error}>
      {field}
    </Field>
  );
});

export interface TextareaProps extends React.TextareaHTMLAttributes<HTMLTextAreaElement> {
  label?: string;
  hint?: string;
  error?: string;
}

export const Textarea = forwardRef<HTMLTextAreaElement, TextareaProps>(function Textarea(
  { label, hint, error, className, id, rows = 4, ...rest },
  ref,
) {
  const gid = useId();
  const fid = id || gid;
  const field = (
    <textarea ref={ref} id={fid} rows={rows} className={cn(fieldBase, borderFor(!!error), 'resize-y px-s4 py-s3', className)} {...rest} />
  );
  if (!label && !hint && !error) return field;
  return (
    <Field label={label} htmlFor={fid} hint={hint} error={error}>
      {field}
    </Field>
  );
});

export interface SelectOption {
  value: string;
  label: string;
}

export interface SelectProps extends React.SelectHTMLAttributes<HTMLSelectElement> {
  label?: string;
  hint?: string;
  error?: string;
  options: SelectOption[];
  placeholder?: string;
}

export const Select = forwardRef<HTMLSelectElement, SelectProps>(function Select(
  { label, hint, error, options, placeholder, className, id, ...rest },
  ref,
) {
  const gid = useId();
  const fid = id || gid;
  const field = (
    <div className="relative">
      <select
        ref={ref}
        id={fid}
        className={cn(fieldBase, borderFor(!!error), 'h-11 appearance-none px-s4 pr-s10', className)}
        {...rest}
      >
        {placeholder && <option value="">{placeholder}</option>}
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
      <Icon
        name="expand_more"
        size={20}
        className="pointer-events-none absolute right-s3 top-1/2 -translate-y-1/2 text-on-surface-variant"
      />
    </div>
  );
  if (!label && !hint && !error) return field;
  return (
    <Field label={label} htmlFor={fid} hint={hint} error={error}>
      {field}
    </Field>
  );
});

export interface CheckboxProps extends Omit<React.InputHTMLAttributes<HTMLInputElement>, 'type'> {
  label?: string;
}

export function Checkbox({ label, className, id, ...rest }: CheckboxProps) {
  const gid = useId();
  const fid = id || gid;
  return (
    <label htmlFor={fid} className={cn('inline-flex cursor-pointer items-center gap-s2 ak-body-md', className)}>
      <input
        id={fid}
        type="checkbox"
        className="h-[18px] w-[18px] rounded-[3px] border-2 border-outline-variant text-primary accent-primary focus-visible:ring-2 focus-visible:ring-primary/40"
        {...rest}
      />
      {label && <span>{label}</span>}
    </label>
  );
}

export interface SwitchProps {
  checked: boolean;
  onChange: (value: boolean) => void;
  label?: string;
  disabled?: boolean;
}

export function Switch({ checked, onChange, label, disabled }: SwitchProps) {
  return (
    <label className={cn('inline-flex items-center gap-s2', disabled ? 'opacity-50' : 'cursor-pointer')}>
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        disabled={disabled}
        onClick={() => onChange(!checked)}
        className={cn(
          'relative h-6 w-11 rounded-full transition-colors duration-fast',
          checked ? 'bg-primary' : 'bg-surface-highest',
        )}
      >
        <span
          className={cn(
            'absolute top-[3px] h-[18px] w-[18px] rounded-full bg-surface shadow-ak-1 transition-transform duration-fast',
            checked ? 'translate-x-[22px]' : 'translate-x-[3px]',
          )}
        />
      </button>
      {label && <span className="ak-body-md">{label}</span>}
    </label>
  );
}
