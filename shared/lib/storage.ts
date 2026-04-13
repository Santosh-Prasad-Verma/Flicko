/**
 * Platform-agnostic storage adapter
 * Uses localStorage for web and AsyncStorage for React Native
 */

interface StorageAdapter {
  getItem: (key: string) => Promise<string | null>;
  setItem: (key: string, value: string) => Promise<void>;
  removeItem: (key: string) => Promise<void>;
}

// Detect platform and create appropriate storage adapter
const createStorageAdapter = (): StorageAdapter => {
  // Check if we're in a React Native environment
  if (typeof window === 'undefined' || !window.localStorage) {
    // React Native - will be dynamically imported
    return {
      getItem: async (key: string) => {
        try {
          const AsyncStorage = await import('@react-native-async-storage/async-storage').then(
            (m) => m.default
          );
          return await AsyncStorage.getItem(key);
        } catch (error) {
          console.error('AsyncStorage not available:', error);
          return null;
        }
      },
      setItem: async (key: string, value: string) => {
        try {
          const AsyncStorage = await import('@react-native-async-storage/async-storage').then(
            (m) => m.default
          );
          await AsyncStorage.setItem(key, value);
        } catch (error) {
          console.error('AsyncStorage not available:', error);
        }
      },
      removeItem: async (key: string) => {
        try {
          const AsyncStorage = await import('@react-native-async-storage/async-storage').then(
            (m) => m.default
          );
          await AsyncStorage.removeItem(key);
        } catch (error) {
          console.error('AsyncStorage not available:', error);
        }
      },
    };
  }

  // Web - use localStorage
  return {
    getItem: async (key: string) => {
      try {
        return localStorage.getItem(key);
      } catch (error) {
        console.error('localStorage not available:', error);
        return null;
      }
    },
    setItem: async (key: string, value: string) => {
      try {
        localStorage.setItem(key, value);
      } catch (error) {
        console.error('localStorage not available:', error);
      }
    },
    removeItem: async (key: string) => {
      try {
        localStorage.removeItem(key);
      } catch (error) {
        console.error('localStorage not available:', error);
      }
    },
  };
};

export const storage = createStorageAdapter();

/**
 * Zustand storage adapter that works on both web and mobile
 */
export const createZustandStorage = () => ({
  getItem: async (name: string): Promise<string | null> => {
    return await storage.getItem(name);
  },
  setItem: async (name: string, value: string): Promise<void> => {
    await storage.setItem(name, value);
  },
  removeItem: async (name: string): Promise<void> => {
    await storage.removeItem(name);
  },
});
