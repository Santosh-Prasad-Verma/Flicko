import { create } from 'zustand';

/**
 * Context menu item definition
 */
export interface ContextMenuItem {
  id: string;
  label: string;
  icon?: string;
  disabled?: boolean;
  danger?: boolean;
  separator?: boolean;
  onClick?: () => void;
}

/**
 * Context Menu Store
 * Manages context menu state, position, and items
 */
interface ContextMenuStore {
  isOpen: boolean;
  position: { x: number; y: number };
  items: ContextMenuItem[];

  openMenu: (position: { x: number; y: number }, items: ContextMenuItem[]) => void;
  closeMenu: () => void;
}

export const useContextMenuStore = create<ContextMenuStore>((set) => ({
  isOpen: false,
  position: { x: 0, y: 0 },
  items: [],

  openMenu: (position, items) =>
    set({
      isOpen: true,
      position,
      items,
    }),

  closeMenu: () =>
    set({
      isOpen: false,
      position: { x: 0, y: 0 },
      items: [],
    }),
}));
