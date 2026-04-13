/**
 * Shared QueryClient instance.
 *
 * Centralised so that non-component code (e.g. auth.service logout)
 * can clear the cache without needing React context.
 */
import { QueryClient } from '@tanstack/react-query';
import {
  QUERY_DEFAULT_RETRIES,
  QUERY_STALE_TIME_MS,
  QUERY_GC_TIME_MS,
} from '@shared/constants/limits';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: QUERY_DEFAULT_RETRIES,
      staleTime: QUERY_STALE_TIME_MS,
      gcTime: QUERY_GC_TIME_MS,
    },
  },
});
