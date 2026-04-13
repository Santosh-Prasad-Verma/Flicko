import { create } from 'zustand';

export type ToastType = 'info' | 'success' | 'warning' | 'error';

export interface Toast {
  id: string;
  type: ToastType;
  title?: string;
  message: string;
  duration: number;
  createdAt: number;
}

interface NotificationState {
  toasts: Toast[];
  unreadByChannel: Record<string, number>;
  addToast: (toast: Omit<Toast, 'id' | 'createdAt'>) => void;
  removeToast: (id: string) => void;
  markChannelRead: (channelId: string) => void;
  incrementUnread: (channelId: string) => void;
  getTotalUnread: () => number;
}

export const useNotificationStore = create<NotificationState>((set, get) => ({
  toasts: [],
  unreadByChannel: {},

  addToast: (toast) => {
    const id = `toast-${Date.now()}-${Math.random().toString(36).slice(2)}`;
    const newToast: Toast = { ...toast, id, createdAt: Date.now() };
    set((s) => ({ toasts: [...s.toasts, newToast] }));
    setTimeout(() => {
      set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) }));
    }, toast.duration);
  },

  removeToast: (id) =>
    set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) })),

  markChannelRead: (channelId) =>
    set((s) => {
      const { [channelId]: _, ...rest } = s.unreadByChannel;
      return { unreadByChannel: rest };
    }),

  incrementUnread: (channelId) =>
    set((s) => ({
      unreadByChannel: {
        ...s.unreadByChannel,
        [channelId]: (s.unreadByChannel[channelId] ?? 0) + 1,
      },
    })),

  getTotalUnread: () =>
    Object.values(get().unreadByChannel).reduce((a, b) => a + b, 0),
}));
