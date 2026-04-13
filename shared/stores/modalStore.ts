import { create } from 'zustand';

/**
 * Modal types supported by the application
 */
export type ModalType =
  | 'createServer'
  | 'createChannel'
  | 'editServer'
  | 'editChannel'
  | 'deleteServer'
  | 'deleteChannel'
  | 'userSettings'
  | 'quickSwitcher'
  | 'inviteUsers'
  | 'editMessage'
  | 'deleteMessage'
  | 'userProfile'
  | 'imageViewer'
  | null;

/**
 * Modal Store for dialog management
 * Manages modal state and props for all application modals
 */
interface ModalStore {
  activeModal: ModalType;
  modalProps: Record<string, any>;

  openModal: (type: ModalType, props?: Record<string, any>) => void;
  closeModal: () => void;
}

export const useModalStore = create<ModalStore>((set) => ({
  activeModal: null,
  modalProps: {},

  openModal: (type, props = {}) =>
    set({
      activeModal: type,
      modalProps: props,
    }),

  closeModal: () =>
    set({
      activeModal: null,
      modalProps: {},
    }),
}));
