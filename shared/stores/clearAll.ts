import { useAuthStore } from './authStore';
import { useUIStore } from './uiStore';
import { useSettingsStore } from './settingsStore';
import { useModalStore } from './modalStore';
import { useContextMenuStore } from './contextMenuStore';
import { useDraftStore } from './draftStore';
import { useVoiceStore } from './voiceStore';
import { useNotificationStore } from './notificationStore';
import { useMessageStore } from './messageStore';
import { useReadStateStore } from './readStateStore';
import { useUploadStore } from './uploadStore';
import { useOfflineQueueStore } from './offlineQueueStore';
import { useSoundboardStore } from './soundboardStore';
import { useActivityStore } from './activityStore';
import { useBookmarkStore } from './bookmarkStore';
import { useAccountSwitchStore } from './accountSwitchStore';

export const clearAllStores = () => {
  // Common states we can reset directly if a clear or reset method exists.
  // Many zustand stores expose a clear/reset. We check for them dynamically.
  
  const stores = [
    useAuthStore,
    useUIStore,
    useSettingsStore,
    useModalStore,
    useContextMenuStore,
    useDraftStore,
    useVoiceStore,
    useNotificationStore,
    useMessageStore,
    useReadStateStore,
    useUploadStore,
    useOfflineQueueStore,
    useSoundboardStore,
    useActivityStore,
    useBookmarkStore,
    useAccountSwitchStore,
  ];

  for (const store of stores) {
    const state = store.getState() as any;
    if (state.reset) {
      state.reset();
    } else if (state.clear) {
      state.clear();
    } else if (state.clearAll) {
      state.clearAll();
    }
  }
};
