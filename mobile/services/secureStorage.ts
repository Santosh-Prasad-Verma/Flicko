/**
 * Secure Storage Service
 *
 * Wraps expo-secure-store to provide encrypted key-value storage for
 * sensitive data such as authentication tokens. Values are stored in
 * iOS Keychain and Android KeyStore.
 *
 * HIGH-010: Added checksum verification for chunked storage integrity.
 * Requirements: 2.2, 2.5, 37.1
 */
import * as SecureStore from 'expo-secure-store';
import * as Crypto from 'expo-crypto';
import { Platform } from 'react-native';
import { STORAGE_KEYS } from '../constants/Config';

/** Options passed to SecureStore methods */
const SECURE_STORE_OPTIONS: SecureStore.SecureStoreOptions = {
  keychainAccessible: SecureStore.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
};
const SECURE_STORE_VALUE_LIMIT_BYTES = 2048;
const SECURE_STORE_CHUNK_SIZE_BYTES = 1800;
const CHUNK_META_SUFFIX = '.chunks';
const CHUNK_DATA_PREFIX = '.chunk.';

/** HIGH-010: Chunk metadata with checksum for integrity verification */
interface ChunkMetadata {
  count: number;
  checksum: string;
  version: number;
}

function getChunkMetaKey(key: string): string {
  return `${key}${CHUNK_META_SUFFIX}`;
}

function getChunkKey(key: string, index: number): string {
  return `${key}${CHUNK_DATA_PREFIX}${index}`;
}

function getUtf8ByteLength(value: string): number {
  let bytes = 0;

  for (let i = 0; i < value.length; i++) {
    const codePoint = value.charCodeAt(i);

    if (codePoint >= 0xd800 && codePoint < 0xe000) {
      if (codePoint < 0xdc00 && i + 1 < value.length) {
        const next = value.charCodeAt(i + 1);
        if (next >= 0xdc00 && next < 0xe000) {
          bytes += 4;
          i += 1;
          continue;
        }
      }
    }

    bytes += codePoint < 0x80 ? 1 : codePoint < 0x800 ? 2 : 3;
  }

  return bytes;
}

function splitByUtf8ByteLength(value: string, maxBytes: number): string[] {
  if (!value) {
    return [''];
  }

  const chunks: string[] = [];
  let chunkStart = 0;
  let currentChunkBytes = 0;

  for (let i = 0; i < value.length; i++) {
    const codePoint = value.charCodeAt(i);
    let charBytes = 0;
    let charLength = 1;

    if (codePoint >= 0xd800 && codePoint < 0xe000) {
      if (codePoint < 0xdc00 && i + 1 < value.length) {
        const next = value.charCodeAt(i + 1);
        if (next >= 0xdc00 && next < 0xe000) {
          charBytes = 4;
          charLength = 2;
        }
      }
    }

    if (charBytes === 0) {
      charBytes = codePoint < 0x80 ? 1 : codePoint < 0x800 ? 2 : 3;
    }

    if (currentChunkBytes + charBytes > maxBytes && i > chunkStart) {
      chunks.push(value.slice(chunkStart, i));
      chunkStart = i;
      currentChunkBytes = 0;
    }

    currentChunkBytes += charBytes;

    if (charLength === 2) {
      i += 1;
    }
  }

  if (chunkStart < value.length) {
    chunks.push(value.slice(chunkStart));
  }

  return chunks;
}

async function getStoredChunkCount(key: string): Promise<number> {
  const raw = await SecureStore.getItemAsync(
    getChunkMetaKey(key),
    SECURE_STORE_OPTIONS,
  );
  if (!raw) return 0;

  // HIGH-010: Try parsing as JSON metadata first (new format)
  try {
    const metadata: ChunkMetadata = JSON.parse(raw);
    if (metadata.version && metadata.count > 0) {
      return metadata.count;
    }
  } catch {
    // Fall back to old plain number format
  }

  const parsedCount = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsedCount) || parsedCount <= 0) {
    return 0;
  }

  return parsedCount;
}

async function clearChunkedValue(key: string): Promise<void> {
  const chunkCount = await getStoredChunkCount(key);

  if (chunkCount > 0) {
    await Promise.allSettled(
      Array.from({ length: chunkCount }, (_, index) =>
        SecureStore.deleteItemAsync(getChunkKey(key, index), SECURE_STORE_OPTIONS),
      ),
    );
  }

  await SecureStore.deleteItemAsync(getChunkMetaKey(key), SECURE_STORE_OPTIONS);
}

/**
 * Store a value securely.
 *
 * @param key   – One of the well-known STORAGE_KEYS
 * @param value – String value to persist (tokens, JSON, etc.)
 */
export async function setSecureItem(key: string, value: string): Promise<void> {
  try {
    if (Platform.OS === 'web') {
      // Fallback for Expo web (dev only – not truly secure)
      localStorage.setItem(key, value);
      return;
    }

    const valueByteLength = getUtf8ByteLength(value);

    if (valueByteLength <= SECURE_STORE_VALUE_LIMIT_BYTES) {
      await SecureStore.setItemAsync(key, value, SECURE_STORE_OPTIONS);
      await clearChunkedValue(key);
      return;
    }

    const previousChunkCount = await getStoredChunkCount(key);
    const chunks = splitByUtf8ByteLength(value, SECURE_STORE_CHUNK_SIZE_BYTES);

    // HIGH-010: Compute SHA-256 checksum of the full value for integrity verification
    const checksum = await Crypto.digestStringAsync(
      Crypto.CryptoDigestAlgorithm.SHA256,
      value,
    );

    await Promise.all(
      chunks.map((chunk, index) =>
        SecureStore.setItemAsync(getChunkKey(key, index), chunk, SECURE_STORE_OPTIONS),
      ),
    );

    // Store metadata with chunk count, checksum, and version
    const metadata: ChunkMetadata = {
      count: chunks.length,
      checksum,
      version: 2,
    };
    await SecureStore.setItemAsync(
      getChunkMetaKey(key),
      JSON.stringify(metadata),
      SECURE_STORE_OPTIONS,
    );
    await SecureStore.deleteItemAsync(key, SECURE_STORE_OPTIONS);

    if (previousChunkCount > chunks.length) {
      await Promise.allSettled(
        Array.from(
          { length: previousChunkCount - chunks.length },
          (_, index) => SecureStore.deleteItemAsync(
            getChunkKey(key, chunks.length + index),
            SECURE_STORE_OPTIONS,
          ),
        ),
      );
    }
  } catch (error) {
    console.error(`[SecureStorage] Failed to set item "${key}"`, error);
    throw new Error(`SecureStorage.setItem failed for key "${key}"`);
  }
}

/**
 * Retrieve a value from secure storage.
 *
 * @param key – One of the well-known STORAGE_KEYS
 * @returns   The stored string or null if not found
 */
export async function getSecureItem(key: string): Promise<string | null> {
  try {
    if (Platform.OS === 'web') {
      return localStorage.getItem(key);
    }

    const chunkCount = await getStoredChunkCount(key);
    if (chunkCount > 0) {
      const chunks = await Promise.all(
        Array.from({ length: chunkCount }, (_, index) =>
          SecureStore.getItemAsync(getChunkKey(key, index), SECURE_STORE_OPTIONS),
        ),
      );

      if (chunks.some((chunk) => chunk === null)) {
        console.warn(`[SecureStorage] Missing chunk data for key "${key}", clearing corrupted entry`);
        await clearChunkedValue(key);
        return null;
      }

      const assembled = chunks.join('');

      // HIGH-010: Verify checksum integrity if metadata has one
      const rawMeta = await SecureStore.getItemAsync(
        getChunkMetaKey(key),
        SECURE_STORE_OPTIONS,
      );
      if (rawMeta) {
        try {
          const metadata: ChunkMetadata = JSON.parse(rawMeta);
          if (metadata.checksum) {
            const currentChecksum = await Crypto.digestStringAsync(
              Crypto.CryptoDigestAlgorithm.SHA256,
              assembled,
            );
            if (currentChecksum !== metadata.checksum) {
              console.error(
                `[SecureStorage] Checksum mismatch for key "${key}". Data may be corrupted. Clearing.`,
              );
              await clearChunkedValue(key);
              return null;
            }
          }
        } catch {
          // Old format (plain number) – no checksum to verify, pass through
        }
      }

      return assembled;
    }

    return await SecureStore.getItemAsync(key, SECURE_STORE_OPTIONS);
  } catch (error) {
    console.error(`[SecureStorage] Failed to get item "${key}"`, error);
    return null;
  }
}

/**
 * Remove a single item from secure storage.
 *
 * @param key – One of the well-known STORAGE_KEYS
 */
export async function removeSecureItem(key: string): Promise<void> {
  try {
    if (Platform.OS === 'web') {
      localStorage.removeItem(key);
      return;
    }
    await clearChunkedValue(key);
    await SecureStore.deleteItemAsync(key, SECURE_STORE_OPTIONS);
  } catch (error) {
    console.error(`[SecureStorage] Failed to remove item "${key}"`, error);
  }
}

/**
 * Clear ALL Flicko-related secure storage entries.
 * Used on logout to wipe tokens and biometric flags.
 */
export async function clearSecureStorage(): Promise<void> {
  const keys = Object.values(STORAGE_KEYS);
  const results = await Promise.allSettled(
    keys.map((key) => removeSecureItem(key)),
  );
  const failures = results.filter((r) => r.status === 'rejected');
  if (failures.length > 0) {
    console.warn(
      `[SecureStorage] ${failures.length} key(s) failed to clear`,
    );
  }
}

/**
 * Supabase-compatible storage adapter that stores auth tokens in
 * SecureStore (iOS Keychain / Android KeyStore).
 *
 * Pass this into the Supabase client's `auth.storage` option so that
 * access & refresh tokens are never stored in plain AsyncStorage.
 */
export const supabaseSecureStorage = {
  getItem: async (key: string): Promise<string | null> => {
    return getSecureItem(key);
  },
  setItem: async (key: string, value: string): Promise<void> => {
    await setSecureItem(key, value);
  },
  removeItem: async (key: string): Promise<void> => {
    await removeSecureItem(key);
  },
};
