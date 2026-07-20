import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Icon } from '@/components/Icon';
import { IconButton } from '@/components/ui';
import { useTheme } from '@/theme/ThemeProvider';
import { RoleSwitcher } from './RoleSwitcher';
import { CommandPalette, usePaletteHotkey } from './CommandPalette';

export interface TopbarProps {
  onOpenMenu: () => void;
  title?: string;
}

export function Topbar({ onOpenMenu, title }: TopbarProps) {
  const { resolved, toggle } = useTheme();
  const navigate = useNavigate();
  const [paletteOpen, setPaletteOpen] = useState(false);
  usePaletteHotkey(setPaletteOpen);

  return (
    <header className="sticky top-0 z-30 flex h-16 items-center gap-s3 border-b border-outline-variant/70 bg-surface/90 px-s4 backdrop-blur">
      <button
        onClick={onOpenMenu}
        aria-label="Open menu"
        className="grid h-10 w-10 place-items-center rounded-full text-on-surface-variant hover:bg-surface-low lg:hidden"
      >
        <Icon name="menu" size={24} />
      </button>

      {title && <h2 className="ak-title-md hidden text-on-surface md:block">{title}</h2>}

      <button
        onClick={() => setPaletteOpen(true)}
        className="ml-auto flex h-10 w-full max-w-sm items-center gap-s2 rounded-full border border-outline-variant bg-surface-low px-s4 text-on-surface-variant transition-colors hover:bg-surface-container"
      >
        <Icon name="search" size={20} />
        <span className="ak-body-md">Search students, staff, actions…</span>
        <kbd className="ml-auto hidden rounded border border-outline-variant bg-surface px-s1 text-[11px] md:inline">⌘K</kbd>
      </button>

      <div className="ml-auto flex items-center gap-s1 lg:ml-0">
        <IconButton icon={resolved === 'dark' ? 'light_mode' : 'dark_mode'} label="Toggle theme" onClick={toggle} />
        <IconButton icon="notifications" label="Notifications" onClick={() => navigate('/notifications')} />
        <IconButton icon="help" label="Help" onClick={() => setPaletteOpen(true)} />
        <div className="mx-s1 h-6 w-px bg-outline-variant/70" />
        <RoleSwitcher />
      </div>

      <CommandPalette open={paletteOpen} onClose={() => setPaletteOpen(false)} />
    </header>
  );
}
