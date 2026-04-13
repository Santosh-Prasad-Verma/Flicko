/**
 * Upload Store (Zustand)
 *
 * Tracks active file uploads with progress, supports cancellation,
 * and manages upload queue for the message input.
 *
 * Requirements: Feature 9 (File Upload Infrastructure)
 */
import { create } from 'zustand';

// ── Types ─────────────────────────────────────────────────────────────────

export type UploadStatus = 'pending' | 'uploading' | 'completed' | 'failed' | 'cancelled';

export interface UploadItem {
  /** Client-generated ID */
  id: string;
  /** Original filename */
  filename: string;
  /** MIME type */
  contentType: string;
  /** Size in bytes */
  size: number;
  /** Local file URI (for preview) */
  localUri: string;
  /** Upload progress 0-1 */
  progress: number;
  /** Current status */
  status: UploadStatus;
  /** Remote URL after upload completes */
  remoteUrl: string | null;
  /** Remote file key/path */
  fileKey: string | null;
  /** Error message if failed */
  error: string | null;
  /** Abort controller for cancellation */
  abortController?: AbortController;
  /** Channel this upload is for */
  channelId: string;
  /** Width (images/video) */
  width?: number;
  /** Height (images/video) */
  height?: number;
  /** Alt text for accessibility */
  altText?: string;
}

export interface UploadStore {
  /** All active/recent uploads keyed by id */
  uploads: Map<string, UploadItem>;

  /** Uploads queued for inclusion in the next message per channel */
  pendingAttachments: Map<string, string[]>; // channelId → uploadId[]

  // ── Actions ───────────────────────────────────────────────────────────

  /** Add a new upload */
  addUpload: (item: Omit<UploadItem, 'progress' | 'status' | 'remoteUrl' | 'fileKey' | 'error'>) => void;

  /** Update upload progress */
  setProgress: (id: string, progress: number) => void;

  /** Set alt text */
  setAltText: (id: string, altText: string) => void;

  /** Mark upload as completed */
  completeUpload: (id: string, remoteUrl: string, fileKey: string) => void;

  /** Mark upload as failed */
  failUpload: (id: string, error: string) => void;

  /** Cancel an in-progress upload */
  cancelUpload: (id: string) => void;

  /** Remove an upload from the list */
  removeUpload: (id: string) => void;

  /** Get uploads for a specific channel */
  getChannelUploads: (channelId: string) => UploadItem[];

  /** Get pending attachment IDs for a channel */
  getPendingAttachments: (channelId: string) => UploadItem[];

  /** Clear completed/failed uploads for a channel */
  clearChannelUploads: (channelId: string) => void;

  /** Clear all uploads */
  reset: () => void;
}

// ── Store ───────────────────────────────────────────────────────────────

export const useUploadStore = create<UploadStore>()((set, get) => ({
  uploads: new Map(),
  pendingAttachments: new Map(),

  addUpload: (item) => {
    const upload: UploadItem = {
      ...item,
      progress: 0,
      status: 'pending',
      remoteUrl: null,
      fileKey: null,
      error: null,
    };

    set((state) => {
      const newUploads = new Map(state.uploads);
      newUploads.set(item.id, upload);

      const newPending = new Map(state.pendingAttachments);
      const channelList = newPending.get(item.channelId) ?? [];
      newPending.set(item.channelId, [...channelList, item.id]);

      return { uploads: newUploads, pendingAttachments: newPending };
    });
  },

  setProgress: (id, progress) => {
    set((state) => {
      const upload = state.uploads.get(id);
      if (!upload) return state;

      const newUploads = new Map(state.uploads);
      newUploads.set(id, { ...upload, progress, status: 'uploading' });
      return { uploads: newUploads };
    });
  },

  setAltText: (id, altText) => {
    set((state) => {
      const upload = state.uploads.get(id);
      if (!upload) return state;

      const newUploads = new Map(state.uploads);
      newUploads.set(id, { ...upload, altText });
      return { uploads: newUploads };
    });
  },

  completeUpload: (id, remoteUrl, fileKey) => {
    set((state) => {
      const upload = state.uploads.get(id);
      if (!upload) return state;

      const newUploads = new Map(state.uploads);
      newUploads.set(id, {
        ...upload,
        progress: 1,
        status: 'completed',
        remoteUrl,
        fileKey,
      });
      return { uploads: newUploads };
    });
  },

  failUpload: (id, error) => {
    set((state) => {
      const upload = state.uploads.get(id);
      if (!upload) return state;

      const newUploads = new Map(state.uploads);
      newUploads.set(id, { ...upload, status: 'failed', error });
      return { uploads: newUploads };
    });
  },

  cancelUpload: (id) => {
    const upload = get().uploads.get(id);
    if (upload?.abortController) {
      upload.abortController.abort();
    }

    set((state) => {
      const existing = state.uploads.get(id);
      if (!existing) return state;

      const newUploads = new Map(state.uploads);
      newUploads.set(id, { ...existing, status: 'cancelled' });

      // Remove from pending
      const newPending = new Map(state.pendingAttachments);
      const channelList = newPending.get(existing.channelId) ?? [];
      newPending.set(
        existing.channelId,
        channelList.filter((uid) => uid !== id),
      );

      return { uploads: newUploads, pendingAttachments: newPending };
    });
  },

  removeUpload: (id) => {
    set((state) => {
      const upload = state.uploads.get(id);
      if (!upload) return state;

      const newUploads = new Map(state.uploads);
      newUploads.delete(id);

      const newPending = new Map(state.pendingAttachments);
      const channelList = newPending.get(upload.channelId) ?? [];
      newPending.set(
        upload.channelId,
        channelList.filter((uid) => uid !== id),
      );

      return { uploads: newUploads, pendingAttachments: newPending };
    });
  },

  getChannelUploads: (channelId) => {
    const result: UploadItem[] = [];
    get().uploads.forEach((upload) => {
      if (upload.channelId === channelId) result.push(upload);
    });
    return result;
  },

  getPendingAttachments: (channelId) => {
    const ids = get().pendingAttachments.get(channelId) ?? [];
    const result: UploadItem[] = [];
    for (const id of ids) {
      const upload = get().uploads.get(id);
      if (upload && upload.status === 'completed') result.push(upload);
    }
    return result;
  },

  clearChannelUploads: (channelId) => {
    set((state) => {
      const newUploads = new Map(state.uploads);
      state.uploads.forEach((upload, id) => {
        if (upload.channelId === channelId) {
          if (upload.abortController) upload.abortController.abort();
          newUploads.delete(id);
        }
      });

      const newPending = new Map(state.pendingAttachments);
      newPending.delete(channelId);

      return { uploads: newUploads, pendingAttachments: newPending };
    });
  },

  reset: () => {
    // Cancel all active uploads
    get().uploads.forEach((upload) => {
      if (upload.abortController) upload.abortController.abort();
    });
    set({ uploads: new Map(), pendingAttachments: new Map() });
  },
}));
