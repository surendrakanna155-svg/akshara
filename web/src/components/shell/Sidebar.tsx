import { NavLink } from 'react-router-dom';
import { cn } from '@/lib/utils/cn';
import { Icon } from '@/components/Icon';
import { Logo } from '@/components/ui';
import type { NavSection } from '@/routes/navConfig';

export interface SidebarProps {
  sections: NavSection[];
  collapsed: boolean;
  onToggleCollapse: () => void;
  /** Mobile: called when a link is tapped so the overlay drawer can close. */
  onNavigate?: () => void;
}

/** Desktop navigation rail — ports the M15 NavigationRail/Drawer theme. */
export function Sidebar({ sections, collapsed, onToggleCollapse, onNavigate }: SidebarProps) {
  return (
    <aside
      className={cn(
        'flex h-full flex-col border-r border-outline-variant/70 bg-surface transition-[width] duration-standard ease-enter',
        collapsed ? 'w-rail-collapsed' : 'w-rail-expanded',
      )}
    >
      <div className={cn('flex h-16 items-center border-b border-outline-variant/60', collapsed ? 'justify-center px-s2' : 'px-s4')}>
        <Logo showWordmark={!collapsed} size={collapsed ? 34 : 34} />
      </div>

      <nav className="flex-1 overflow-y-auto px-s2 py-s3">
        {sections.map((section) => (
          <div key={section.label} className="mb-s4">
            {!collapsed && (
              <p className="px-s3 pb-s1 ak-label-sm uppercase tracking-wider text-on-surface-variant/70">{section.label}</p>
            )}
            <ul className="space-y-[2px]">
              {section.items.map((item) => (
                <li key={item.key}>
                  <NavLink
                    to={item.path}
                    onClick={onNavigate}
                    title={collapsed ? item.label : undefined}
                    className={({ isActive }) =>
                      cn(
                        'group flex items-center gap-s3 rounded-md px-s3 py-s2 ak-label-lg transition-colors duration-fast',
                        collapsed && 'justify-center px-0',
                        isActive
                          ? 'bg-primary-container font-semibold text-on-primary-container'
                          : 'text-on-surface-variant hover:bg-surface-low hover:text-on-surface',
                      )
                    }
                  >
                    {({ isActive }) => (
                      <>
                        <Icon name={item.icon} size={22} fill={isActive} />
                        {!collapsed && <span className="truncate">{item.label}</span>}
                      </>
                    )}
                  </NavLink>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </nav>

      <button
        onClick={onToggleCollapse}
        className="hidden h-11 items-center gap-s2 border-t border-outline-variant/60 px-s4 text-on-surface-variant transition-colors hover:bg-surface-low lg:flex"
      >
        <Icon name={collapsed ? 'chevron_right' : 'chevron_left'} size={20} />
        {!collapsed && <span className="ak-label-md">Collapse</span>}
      </button>
    </aside>
  );
}
