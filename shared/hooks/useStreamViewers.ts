/**
 * useStreamViewers — React Query hooks for stream viewer data
 */
import * as streamService from '../services/streamService';
import { useEffect, useState, useCallback } from 'react';

export function useStreamViewers(streamId: string | null) {
  const [data, setData] = useState<streamService.StreamViewer[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const fetch = useCallback(async () => {
    if (!streamId) return;
    setIsLoading(true);
    try {
      const viewers = await streamService.getStreamViewers(streamId);
      setData(viewers);
      setError(null);
    } catch (e) {
      setError(e as Error);
    } finally {
      setIsLoading(false);
    }
  }, [streamId]);

  useEffect(() => {
    fetch();
    // Refetch every 10s as backup
    const interval = setInterval(fetch, 10_000);
    return () => clearInterval(interval);
  }, [fetch]);

  return { data, isLoading, error, refetch: fetch };
}

export function useActiveStreams(channelId: string) {
  const [data, setData] = useState<streamService.Stream[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const fetch = useCallback(async () => {
    if (!channelId) return;
    setIsLoading(true);
    try {
      const streams = await streamService.getActiveStreams(channelId);
      setData(streams);
      setError(null);
    } catch (e) {
      setError(e as Error);
    } finally {
      setIsLoading(false);
    }
  }, [channelId]);

  useEffect(() => {
    fetch();
    const interval = setInterval(fetch, 15_000);
    return () => clearInterval(interval);
  }, [fetch]);

  return { data, isLoading, error, refetch: fetch };
}

export function useServerStreams(serverId: string) {
  const [data, setData] = useState<streamService.Stream[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const fetch = useCallback(async () => {
    if (!serverId) return;
    setIsLoading(true);
    try {
      const streams = await streamService.getServerActiveStreams(serverId);
      setData(streams);
      setError(null);
    } catch (e) {
      setError(e as Error);
    } finally {
      setIsLoading(false);
    }
  }, [serverId]);

  useEffect(() => {
    fetch();
    const interval = setInterval(fetch, 15_000);
    return () => clearInterval(interval);
  }, [fetch]);

  return { data, isLoading, error, refetch: fetch };
}
