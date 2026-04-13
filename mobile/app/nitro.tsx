/**
 * Nitro redirect — consolidated into Flicko Plus.
 * This route exists to redirect any old /nitro links to /flicko-plus.
 */
import { useEffect } from 'react';
import { router } from 'expo-router';

export default function NitroRedirect() {
  useEffect(() => {
    router.replace('/flicko-plus' as any);
  }, []);

  return null;
}
