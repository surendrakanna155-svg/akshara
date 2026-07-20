import { useEffect, useState } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { Icon } from '@/components/Icon';

/** Global offline banner — ports lib/core/reliability/sync_center/sync_banner.dart.
 *  Hidden unless the browser is offline. */
export function SyncBanner() {
  const [online, setOnline] = useState(() => navigator.onLine);
  useEffect(() => {
    const on = () => setOnline(true);
    const off = () => setOnline(false);
    window.addEventListener('online', on);
    window.addEventListener('offline', off);
    return () => {
      window.removeEventListener('online', on);
      window.removeEventListener('offline', off);
    };
  }, []);

  return (
    <AnimatePresence>
      {!online && (
        <motion.div
          initial={{ y: 40, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          exit={{ y: 40, opacity: 0 }}
          className="flex items-center justify-center gap-s2 bg-warning-container px-s4 py-s2 ak-label-md text-warning"
        >
          <Icon name="cloud_off" size={18} />
          You are offline — changes will sync automatically when the connection returns.
        </motion.div>
      )}
    </AnimatePresence>
  );
}
