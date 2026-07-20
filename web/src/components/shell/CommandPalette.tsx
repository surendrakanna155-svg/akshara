import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { AnimatePresence, motion } from 'framer-motion';
import { Icon } from '@/components/Icon';
import { useAuth } from '@/lib/auth/AuthContext';
import { ERP_NAV, PORTAL_NAV, navForRole, workspaceForRole } from '@/routes/navConfig';
import type { NavItem } from '@/routes/navConfig';
import { canAccess } from '@/lib/auth/roles';
import { cn } from '@/lib/utils/cn';

/** Universal search / command palette (⌘K). Ports the copilot universal search intent. */
export function CommandPalette({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [q, setQ] = useState('');
  const [active, setActive] = useState(0);

  const items = useMemo<NavItem[]>(() => {
    if (!user) return [];
    const ws = workspaceForRole(user.role);
    if (ws === 'teacher' || ws === 'parent' || ws === 'student') return PORTAL_NAV[ws];
    return navForRole(user.role).flatMap((s) => s.items);
  }, [user]);

  const results = useMemo(() => {
    const term = q.trim().toLowerCase();
    const base = term ? items.filter((i) => i.label.toLowerCase().includes(term)) : items;
    return base.filter((i) => !user || canAccess(user.role, i.moduleKey)).slice(0, 8);
  }, [q, items, user]);

  useEffect(() => {
    if (open) {
      setQ('');
      setActive(0);
    }
  }, [open]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        open ? onClose() : window.dispatchEvent(new CustomEvent('akshara:open-palette'));
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  function go(item: NavItem) {
    navigate(item.path);
    onClose();
  }

  return (
    <AnimatePresence>
      {open && (
        <div className="fixed inset-0 z-[60] flex items-start justify-center p-s4 pt-[12vh]">
          <motion.div
            className="absolute inset-0 bg-[rgb(var(--ak-scrim)/0.45)]"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
          />
          <motion.div
            initial={{ opacity: 0, y: -8, scale: 0.98 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -8, scale: 0.98 }}
            transition={{ duration: 0.16 }}
            className="relative z-10 w-full max-w-xl overflow-hidden rounded-2xl border border-outline-variant/55 bg-surface shadow-ak-5"
          >
            <div className="flex items-center gap-s3 border-b border-outline-variant/60 px-s4">
              <Icon name="search" size={22} className="text-on-surface-variant" />
              <input
                autoFocus
                value={q}
                onChange={(e) => {
                  setQ(e.target.value);
                  setActive(0);
                }}
                onKeyDown={(e) => {
                  if (e.key === 'ArrowDown') setActive((a) => Math.min(a + 1, results.length - 1));
                  if (e.key === 'ArrowUp') setActive((a) => Math.max(a - 1, 0));
                  if (e.key === 'Enter' && results[active]) go(results[active]);
                }}
                placeholder="Search or jump to…"
                className="h-14 w-full bg-transparent ak-body-lg text-on-surface outline-none placeholder:text-on-surface-variant"
              />
              <kbd className="rounded border border-outline-variant px-s1 text-[11px] text-on-surface-variant">esc</kbd>
            </div>
            <ul className="max-h-80 overflow-y-auto p-s2">
              {results.map((item, i) => (
                <li key={item.key}>
                  <button
                    onMouseEnter={() => setActive(i)}
                    onClick={() => go(item)}
                    className={cn(
                      'flex w-full items-center gap-s3 rounded-md px-s3 py-s2 text-left',
                      i === active ? 'bg-primary-container text-on-primary-container' : 'text-on-surface hover:bg-surface-low',
                    )}
                  >
                    <Icon name={item.icon} size={20} />
                    <span className="ak-body-md">{item.label}</span>
                    <Icon name="north_east" size={16} className="ml-auto opacity-50" />
                  </button>
                </li>
              ))}
              {results.length === 0 && <li className="px-s3 py-s4 ak-body-md text-on-surface-variant">No matches.</li>}
            </ul>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  );
}

/** Hook the ⌘K global open event to a setter. */
export function usePaletteHotkey(setOpen: (v: boolean) => void) {
  useEffect(() => {
    const handler = () => setOpen(true);
    window.addEventListener('akshara:open-palette', handler);
    return () => window.removeEventListener('akshara:open-palette', handler);
  }, [setOpen]);
}

export { ERP_NAV };
