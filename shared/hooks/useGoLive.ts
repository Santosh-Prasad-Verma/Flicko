/**
 * useGoLive — Hook for Go Live (streaming) functionality
 */
import { useCallback, useEffect, useState } from 'react';
import { useVoiceStore } from '../stores/voiceStore';
import { mediaService, StreamConfig } from '../services/mediaService';
import * as streamService from '../services/streamService';
import type { Stream, StreamViewer } from '../services/streamService';
import { RealtimeChannel } from '@supabase/supabase-js';

export function useGoLive(channelId: string) {
  const store = useVoiceStore();
  const [activeStreams, setActiveStreams] = useState<Stream[]>([]);
  const [viewerCount, setViewerCount] = useState(0);
  const [viewers, setViewers] = useState<StreamViewer[]>([]);
  const [loading, setLoading] = useState(false);

  // ── Fetch active streams ──

  const fetchStreams = useCallback(async () => {
    try {
      const streams = await streamService.getActiveStreams(channelId);
      setActiveStreams(streams);
    } catch (error) {
      console.error('Failed to fetch streams:', error);
    }
  }, [channelId]);

  // ── Start Go Live ──

  const goLive = useCallback(async (config: Omit<StreamConfig, 'channelId' | 'serverId'>) => {
    if (!store.serverId || !store.channelId) throw new Error('Not in a voice channel');
    setLoading(true);

    try {
      const streamId = await mediaService.startGoLive({
        channelId: store.channelId,
        serverId: store.serverId,
        ...config,
      });
      await fetchStreams();
      return streamId;
    } finally {
      setLoading(false);
    }
  }, [store.serverId, store.channelId, fetchStreams]);

  // ── End Go Live ──

  const endGoLive = useCallback(async () => {
    if (!store.activeStreamId) return;
    setLoading(true);

    try {
      await mediaService.endStream(store.activeStreamId);
      await fetchStreams();
    } finally {
      setLoading(false);
    }
  }, [store.activeStreamId, fetchStreams]);

  // ── Watch/Stop Watching ──

  const watchStream = useCallback(async (streamId: string) => {
    await mediaService.watchStream(streamId);
    const streamViewers = await streamService.getStreamViewers(streamId);
    setViewers(streamViewers);
  }, []);

  const stopWatching = useCallback(async () => {
    if (!store.watchingStreamId) return;
    await mediaService.stopWatchingStream(store.watchingStreamId);
    setViewers([]);
  }, [store.watchingStreamId]);

  // ── Realtime subscription ──

  useEffect(() => {
    fetchStreams();

    const streamSub = streamService.subscribeToChannelStreams(channelId, {
      onStreamStarted: () => fetchStreams(),
      onStreamUpdated: () => fetchStreams(),
      onStreamEnded: () => fetchStreams(),
    });

    let viewerSub: RealtimeChannel | null = null;
    if (store.activeStreamId) {
      viewerSub = streamService.subscribeToStreamViewerCount(
        store.activeStreamId,
        setViewerCount
      );
    }

    return () => {
      streamSub.unsubscribe();
      viewerSub?.unsubscribe();
    };
  }, [channelId, store.activeStreamId]);

  return {
    activeStreams,
    viewerCount,
    viewers,
    loading,
    isLive: !!store.activeStreamId,
    goLive,
    endGoLive,
    watchStream,
    stopWatching,
  };
}
