/**
 * Crypto Polyfills for React Native / AWS SDK / uuid
 *
 * MUST be imported as the very first import in index.ts.
 * ESM hoisting evaluates imports before inline code, so this needs
 * to be a separate module to ensure crypto.getRandomValues and
 * crypto.subtle are available before any other module evaluates
 * (especially uuid which caches getRandomValues at module load time).
 */
import * as ExpoCrypto from 'expo-crypto';

const globalScope = globalThis as any;

if (!globalScope.crypto) {
  globalScope.crypto = {};
}

// ── 1. Polyfill crypto.getRandomValues ────────────────────────────────────
// Required by uuid (used by @aws-sdk) which captures this at module load.
if (typeof globalScope.crypto.getRandomValues !== 'function') {
  globalScope.crypto.getRandomValues = <T extends ArrayBufferView>(array: T): T => {
    ExpoCrypto.getRandomValues(array as any);
    return array;
  };
}

// ── 2. Polyfill crypto.subtle ─────────────────────────────────────────────
// Required by @aws-sdk/client-s3 for HMAC-SHA256 request signing.
if (!globalScope.crypto.subtle) {
  async function sha256(data: ArrayBuffer): Promise<ArrayBuffer> {
    return ExpoCrypto.digest(
      ExpoCrypto.CryptoDigestAlgorithm.SHA256,
      new Uint8Array(data),
    );
  }

  async function hmacSha256(key: ArrayBuffer, data: ArrayBuffer): Promise<ArrayBuffer> {
    const BLOCK_SIZE = 64;
    let keyBytes = new Uint8Array(key);

    if (keyBytes.length > BLOCK_SIZE) {
      keyBytes = new Uint8Array(await sha256(keyBytes.buffer));
    }

    const paddedKey = new Uint8Array(BLOCK_SIZE);
    paddedKey.set(keyBytes);

    const ipad = new Uint8Array(BLOCK_SIZE);
    const opad = new Uint8Array(BLOCK_SIZE);
    for (let i = 0; i < BLOCK_SIZE; i++) {
      ipad[i] = paddedKey[i] ^ 0x36;
      opad[i] = paddedKey[i] ^ 0x5c;
    }

    const innerInput = new Uint8Array(BLOCK_SIZE + data.byteLength);
    innerInput.set(ipad);
    innerInput.set(new Uint8Array(data), BLOCK_SIZE);
    const innerHash = await sha256(innerInput.buffer);

    const outerInput = new Uint8Array(BLOCK_SIZE + 32);
    outerInput.set(opad);
    outerInput.set(new Uint8Array(innerHash), BLOCK_SIZE);
    return sha256(outerInput.buffer);
  }

  class PolyfillCryptoKey {
    constructor(public readonly rawKey: ArrayBuffer) {}
  }

  globalScope.crypto.subtle = {
    async digest(algorithm: any, data: ArrayBuffer): Promise<ArrayBuffer> {
      const name = typeof algorithm === 'string' ? algorithm : algorithm?.name;
      if (name === 'SHA-256' || name === 'sha-256') {
        return sha256(data);
      }
      if (name === 'SHA-1' || name === 'sha-1') {
        return ExpoCrypto.digest(ExpoCrypto.CryptoDigestAlgorithm.SHA1, new Uint8Array(data));
      }
      throw new Error(`Unsupported digest algorithm: ${name}`);
    },

    async importKey(
      _format: string,
      keyData: ArrayBuffer | Uint8Array,
      _algorithm: any,
      _extractable: boolean,
      _keyUsages: string[],
    ): Promise<any> {
      const raw = keyData instanceof Uint8Array ? keyData.buffer : keyData;
      return new PolyfillCryptoKey(raw);
    },

    async sign(_algorithm: any, key: any, data: ArrayBuffer): Promise<ArrayBuffer> {
      if (key instanceof PolyfillCryptoKey) {
        return hmacSha256(key.rawKey, data);
      }
      throw new Error('Unsupported key type for sign operation');
    },

    async verify(
      _algorithm: any,
      key: any,
      signature: ArrayBuffer,
      data: ArrayBuffer,
    ): Promise<boolean> {
      if (key instanceof PolyfillCryptoKey) {
        const expected = new Uint8Array(await hmacSha256(key.rawKey, data));
        const actual = new Uint8Array(signature);
        if (expected.length !== actual.length) return false;
        for (let i = 0; i < expected.length; i++) {
          if (expected[i] !== actual[i]) return false;
        }
        return true;
      }
      throw new Error('Unsupported key type for verify operation');
    },
  };
}
