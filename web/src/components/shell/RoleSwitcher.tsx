import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { AnimatePresence, motion } from 'framer-motion';
import { AUTH_IS_DEMO, useAuth } from '@/lib/auth/AuthContext';
import { DEMO_ROLES, ROLE_META } from '@/lib/auth/roles';
import { Icon } from '@/components/Icon';
import { Avatar, useToast } from '@/components/ui';
import { cn } from '@/lib/utils/cn';

/**
 * Topbar identity menu. In DEMO mode it doubles as the persona switcher (mirrors
 * the Flutter demo role picker). In LIVE mode the persona list is hidden — it
 * builds a token-less preview identity and would silently destroy the real
 * signed-in session — leaving only the real Sign out action.
 */
export function RoleSwitcher() {
  const { user, switchRole, logout } = useAuth();
  const navigate = useNavigate();
  const toast = useToast();
  const [open, setOpen] = useState(false);
  if (!user) return null;
  const meta = ROLE_META[user.role];

  return (
    <div className="relative">
      <button
        onClick={() => setOpen((o) => !o)}
        className="flex items-center gap-s2 rounded-full border border-outline-variant bg-surface py-s1 pl-s1 pr-s2 transition-colors hover:bg-surface-low"
      >
        <Avatar name={user.name} size={32} />
        <span className="hidden text-left leading-tight sm:block">
          <span className="block ak-label-md text-on-surface">{user.name}</span>
          <span className="block text-[11px] text-on-surface-variant">{meta.label}</span>
        </span>
        <Icon name="expand_more" size={18} className="text-on-surface-variant" />
      </button>
      <AnimatePresence>
        {open && (
          <>
            <div className="fixed inset-0 z-40" onClick={() => setOpen(false)} />
            <motion.div
              initial={{ opacity: 0, y: -6, scale: 0.98 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: -6, scale: 0.98 }}
              transition={{ duration: 0.14 }}
              className="absolute right-0 z-50 mt-s2 w-72 overflow-hidden rounded-xl border border-outline-variant bg-surface shadow-ak-4"
            >
              <div className="border-b border-outline-variant/60 px-s4 py-s3">
                <p className="ak-label-md text-on-surface">{user.name}</p>
                <p className="ak-label-sm text-on-surface-variant">
                  {meta.label}
                  {user.schoolName ? ` · ${user.schoolName}` : ''}
                </p>
              </div>
              {/* Persona switching invents a token-less identity — DEMO only. */}
              {AUTH_IS_DEMO && (
                <div className="max-h-72 overflow-y-auto border-b border-outline-variant/60 p-s2">
                  <p className="px-s3 py-s1 ak-label-sm uppercase tracking-wide text-on-surface-variant">Switch persona (demo)</p>
                  {DEMO_ROLES.map((r) => {
                    const rm = ROLE_META[r];
                    const active = r === user.role;
                    return (
                      <button
                        key={r}
                        onClick={() => {
                          const u = switchRole(r);
                          setOpen(false);
                          navigate(ROLE_META[u.role].landing);
                          toast.success(`Now viewing as ${ROLE_META[u.role].label}`);
                        }}
                        className={cn(
                          'flex w-full items-center gap-s3 rounded-md px-s3 py-s2 text-left transition-colors',
                          active ? 'bg-primary-container text-on-primary-container' : 'hover:bg-surface-low',
                        )}
                      >
                        <span
                          className={cn(
                            'grid h-8 w-8 place-items-center rounded-lg',
                            active ? 'bg-primary text-on-primary' : 'bg-surface-container text-on-surface-variant',
                          )}
                        >
                          <Icon name={rm.icon} size={18} />
                        </span>
                        <span className="ak-body-md">{rm.label}</span>
                        {active && <Icon name="check" size={18} className="ml-auto" />}
                      </button>
                    );
                  })}
                </div>
              )}
              <div className="p-s2">
                <button
                  onClick={() => {
                    setOpen(false);
                    logout();
                    navigate('/login');
                  }}
                  className="flex w-full items-center gap-s3 rounded-md px-s3 py-s2 text-left text-error transition-colors hover:bg-error-container/40"
                >
                  <span className="grid h-8 w-8 place-items-center rounded-lg bg-error-container text-error">
                    <Icon name="logout" size={18} />
                  </span>
                  <span className="ak-body-md">Sign out</span>
                </button>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </div>
  );
}
