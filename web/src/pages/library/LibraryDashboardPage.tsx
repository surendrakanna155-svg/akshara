import { useNavigate } from 'react-router-dom';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { apiFetch } from '@/lib/api/client';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import { Button, KpiCard, PageHeader, StatGrid } from '@/components/ui';
import { ModuleTabs } from '@/components/shell/ModuleTabs';
import type { LibraryDashboardData } from '@/lib/contracts/library';
import { LIBRARY_TABS } from './shared';

const fetchDashboard = () => apiFetch<LibraryDashboardData>('/library/dashboard');
const ICONS = ['menu_book', 'import_contacts', 'groups', 'payments'];

export function LibraryDashboardPage() {
  const navigate = useNavigate();
  const query = useModuleQuery(['library', 'dashboard'], fetchDashboard);
  return (
    <div className="space-y-s6">
      <PageHeader
        title="Library"
        subtitle="Catalog and circulation overview"
        icon="local_library"
        tabs={<ModuleTabs tabs={LIBRARY_TABS} />}
        actions={<Button variant="outlined" icon="menu_book" onClick={() => navigate('/library/catalog')}>Catalog</Button>}
      />
      <AsyncBoundary query={query} unavailableTitle="Library overview is ready" unavailableMessage="Circulation KPIs load here from /library/dashboard once the backend is connected.">
        {(d) => (
          <StatGrid>
            {d.kpis.map((k, i) => (
              <KpiCard key={k.id} label={k.label} value={k.value} icon={ICONS[i % ICONS.length]} delta={k.delta} />
            ))}
          </StatGrid>
        )}
      </AsyncBoundary>
    </div>
  );
}
