import { create } from 'zustand';

/**
 * UI Store for navigation state
 * Tracks active server, channel, DM, and sidebar states
 */
interface UIStore {
  activeServerId: string | null;
  activeChannelId: string | null;
  activeDMUserId: string | null;
  sidebarCollapsed: boolean;
  memberListCollapsed: boolean;

  setActiveServer: (serverId: string | null) => void;
  setActiveChannel: (channelId: string | null) => void;
  setActiveDM: (userId: string | null) => void;
  toggleSidebar: () => void;
  toggleMemberList: () => void;
}

export const useUIStore = create<UIStore>((set) => ({
  activeServerId: null,
  activeChannelId: null,
  activeDMUserId: null,
  sidebarCollapsed: false,
  memberListCollapsed: false,

  setActiveServer: (serverId) => set({ activeServerId: serverId }),
  setActiveChannel: (channelId) => set({ activeChannelId: channelId }),
  setActiveDM: (userId) => set({ activeDMUserId: userId }),
  toggleSidebar: () =>
    set((state) => ({ sidebarCollapsed: !state.sidebarCollapsed })),
  toggleMemberList: () =>
    set((state) => ({ memberListCollapsed: !state.memberListCollapsed })),
}));
