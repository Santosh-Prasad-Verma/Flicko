import { create } from 'zustand';

export type CallStatus = 'ringing' | 'accepted' | 'rejected' | 'ended' | 'missed';
export type CallType = 'voice' | 'video';

export interface DMCall {
  id: string;
  dmId: string;
  callerId: string;
  calleeId: string;
  status: CallStatus;
  callType: CallType;
  roomName: string;
  startedAt: string;
  callerProfile?: {
    username: string;
    avatarUrl: string | null;
  };
}

interface DMCallState {
  currentCall: DMCall | null;
  incomingCall: DMCall | null;
  
  // Actions
  setIncomingCall: (call: DMCall | null) => void;
  setCurrentCall: (call: DMCall | null) => void;
  resetCall: () => void;
}

export const useDMCallStore = create<DMCallState>((set) => ({
  currentCall: null,
  incomingCall: null,

  setIncomingCall: (incomingCall) => set({ incomingCall }),
  setCurrentCall: (currentCall) => set({ currentCall, incomingCall: null }),
  resetCall: () => set({ currentCall: null, incomingCall: null }),
}));
