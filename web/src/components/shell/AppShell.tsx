import { useState } from 'react';
import { Outlet } from 'react-router-dom';
import { AnimatePresence, motion } from 'framer-motion';
import { useAuth } from '@/lib/auth/AuthContext';
import { useGrantedModules } from '@/lib/auth/permissions';
import { navForRole, PORTAL_NAV, workspaceForRole } from '@/routes/navConfig';
import type { NavSection } from '@/routes/navConfig';
import { Sidebar } from './Sidebar';
import { Topbar } from './Topbar';
import { SyncBanner } from './SyncBanner';

/** Root authenticated layout — adapts between the ERP console and role portals. */
export function AppShell() {
  const { user } = useAuth();
  const granted = useGrantedModules();
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  const sections: NavSection[] = (() => {
    if (!user) return [];
    const ws = workspaceForRole(user.role);
    if (ws === 'teacher' || ws === 'parent' || ws === 'student') {
      return [{ label: ws[0].toUpperCase() + ws.slice(1), items: PORTAL_NAV[ws] }];
    }
    return navForRole(user.role, granted);
  })();

  return (
    <div className="flex h-screen overflow-hidden bg-surface-low">
      {/* Desktop rail */}
      <div className="hidden lg:block">
        <Sidebar sections={sections} collapsed={collapsed} onToggleCollapse={() => setCollapsed((c) => !c)} />
      </div>

      {/* Mobile overlay drawer */}
      <AnimatePresence>
        {mobileOpen && (
          <div className="fixed inset-0 z-50 lg:hidden">
            <motion.div
              className="absolute inset-0 bg-[rgb(var(--ak-scrim)/0.45)]"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setMobileOpen(false)}
            />
            <motion.div
              className="absolute left-0 top-0 h-full"
              initial={{ x: -280 }}
              animate={{ x: 0 }}
              exit={{ x: -280 }}
              transition={{ duration: 0.24, ease: [0.215, 0.61, 0.355, 1] }}
            >
              <Sidebar
                sections={sections}
                collapsed={false}
                onToggleCollapse={() => {}}
                onNavigate={() => setMobileOpen(false)}
              />
            </motion.div>
          </div>
        )}
      </AnimatePresence>

      <div className="flex min-w-0 flex-1 flex-col">
        <Topbar onOpenMenu={() => setMobileOpen(true)} />
        <main className="flex-1 overflow-y-auto">
          <div className="mx-auto w-full max-w-frame px-s4 py-s5 sm:px-s6 lg:px-s8">
            <Outlet />
          </div>
        </main>
        <SyncBanner />
      </div>
    </div>
  );
}
