import { NavLink } from 'react-router-dom';
import { cn } from '@/lib/utils/cn';

export interface ModuleTab {
  label: string;
  path: string;
  icon?: string;
}

/** Secondary in-module navigation (ports the Flutter module TabBar). */
export function ModuleTabs({ tabs }: { tabs: ModuleTab[] }) {
  return (
    <div className="flex items-center gap-s1 overflow-x-auto border-b border-outline-variant/65">
      {tabs.map((t) => (
        <NavLink
          key={t.path}
          to={t.path}
          end
          className={({ isActive }) =>
            cn(
              'relative whitespace-nowrap px-s3 py-s3 ak-label-lg transition-colors duration-fast',
              isActive ? 'text-primary' : 'text-on-surface-variant hover:text-on-surface',
            )
          }
        >
          {({ isActive }) => (
            <>
              {t.label}
              {isActive && <span className="absolute inset-x-s2 -bottom-px h-[3px] rounded-full bg-primary" />}
            </>
          )}
        </NavLink>
      ))}
    </div>
  );
}
