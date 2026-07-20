import { cn } from '@/lib/utils/cn';
import { initials as toInitials } from '@/lib/utils/format';

export interface AvatarProps {
  name: string;
  src?: string;
  size?: number;
  className?: string;
}

// Deterministic accent from the name so avatars are stable + varied.
const ACCENTS = [
  'bg-primary-container text-on-primary-container',
  'bg-tertiary-container text-on-tertiary-container',
  'bg-indigo-container text-indigo',
  'bg-secondary-container text-on-secondary-container',
];

export function Avatar({ name, src, size = 40, className }: AvatarProps) {
  // A display primitive must never take a page down: live rows can omit the name
  // even where the contract types it as required.
  const safeName = typeof name === 'string' ? name : '';
  const accent = ACCENTS[Math.abs(hash(safeName)) % ACCENTS.length];
  return (
    <span
      className={cn('inline-grid shrink-0 place-items-center overflow-hidden rounded-full font-semibold', accent, className)}
      style={{ width: size, height: size, fontSize: size * 0.4 }}
    >
      {src ? (
        <img src={src} alt={safeName} className="h-full w-full object-cover" />
      ) : (
        <span>{toInitials(safeName)}</span>
      )}
    </span>
  );
}

function hash(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h << 5) - h + s.charCodeAt(i);
  return h;
}
