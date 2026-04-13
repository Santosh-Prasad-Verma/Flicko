/**
 * Account Switching Store (Feature 16)
 *
 * Manages multiple saved account tokens for quick account switching.
 * Stores in expo-secure-store.
 */
import { create } from 'zustand';
import * as SecureStore from 'expo-secure-store';

export interface SavedAccount {
  id: string;
  email: string;
  username: string;
  displayName?: string;
  avatarUrl?: string;
  accessToken: string;
  refreshToken: string;
}

interface AccountSwitchStore {
  accounts: SavedAccount[];
  activeAccountId: string | null;
  loading: boolean;

  loadAccounts: () => Promise<void>;
  addAccount: (account: SavedAccount) => Promise<void>;
  removeAccount: (accountId: string) => Promise<void>;
  switchAccount: (accountId: string) => Promise<SavedAccount | null>;
  updateAccountTokens: (accountId: string, accessToken: string, refreshToken: string) => Promise<void>;
}

const ACCOUNTS_KEY = 'flicko-multi-accounts';

export const useAccountSwitchStore = create<AccountSwitchStore>()((set, get) => ({
  accounts: [],
  activeAccountId: null,
  loading: false,

  loadAccounts: async () => {
    set({ loading: true });
    try {
      const raw = await SecureStore.getItemAsync(ACCOUNTS_KEY);
      if (raw) {
        const accounts: SavedAccount[] = JSON.parse(raw);
        set({ accounts });
      }
    } catch (err) {
      console.error('[accountSwitchStore] loadAccounts failed:', err);
    } finally {
      set({ loading: false });
    }
  },

  addAccount: async (account) => {
    const accounts = get().accounts.filter((a) => a.id !== account.id);
    accounts.push(account);
    set({ accounts, activeAccountId: account.id });
    try {
      await SecureStore.setItemAsync(ACCOUNTS_KEY, JSON.stringify(accounts));
    } catch (err) {
      console.error('[accountSwitchStore] addAccount failed:', err);
    }
  },

  removeAccount: async (accountId) => {
    const accounts = get().accounts.filter((a) => a.id !== accountId);
    set({ accounts });
    try {
      await SecureStore.setItemAsync(ACCOUNTS_KEY, JSON.stringify(accounts));
    } catch (err) {
      console.error('[accountSwitchStore] removeAccount failed:', err);
    }
  },

  switchAccount: async (accountId) => {
    const account = get().accounts.find((a) => a.id === accountId);
    if (!account) return null;
    set({ activeAccountId: accountId });
    return account;
  },

  updateAccountTokens: async (accountId, accessToken, refreshToken) => {
    const accounts = get().accounts.map((a) =>
      a.id === accountId ? { ...a, accessToken, refreshToken } : a
    );
    set({ accounts });
    try {
      await SecureStore.setItemAsync(ACCOUNTS_KEY, JSON.stringify(accounts));
    } catch (err) {
      console.error('[accountSwitchStore] updateAccountTokens failed:', err);
    }
  },
}));
