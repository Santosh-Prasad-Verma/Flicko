import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../services/supabase';

export function useSlowmodeTimer(channelId: string | null) {
  const [remainingSeconds, setRemainingSeconds] = useState(0);

  const checkSlowmode = useCallback(async () => {
    if (!channelId) {
      setRemainingSeconds(0);
      return;
    }

    try {
      const { data, error } = await supabase
        .rpc('get_slowmode_remaining_seconds', { p_channel_id: channelId });
        
      if (error) {
        // Check if it's a "function not found" error (PGRST202)
        if (error.code === 'PGRST202') {
          // Log warning once and fallback to 0 seconds
          if (!checkSlowmode.hasLoggedMissingFunction) {
            console.warn('[useSlowmodeTimer] Database function get_slowmode_remaining_seconds not found. Slowmode timer disabled. Please apply migration 064.');
            checkSlowmode.hasLoggedMissingFunction = true;
          }
          setRemainingSeconds(0);
          return;
        }
        // For other errors, log but don't spam
        console.error('Error fetching slowmode timer:', error);
        setRemainingSeconds(0);
        return;
      }
      
      const seconds = Number(data) || 0;
      setRemainingSeconds(seconds);
    } catch (e) {
      console.error('Failed to check slowmode timer', e);
      setRemainingSeconds(0);
    }
  }, [channelId]);

  useEffect(() => {
    checkSlowmode();
  }, [checkSlowmode]);

  useEffect(() => {
    if (remainingSeconds <= 0) return;

    const interval = setInterval(() => {
      setRemainingSeconds((prev) => {
        if (prev <= 1) {
          clearInterval(interval);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    return () => clearInterval(interval);
  }, [remainingSeconds]);
  
  // Re-check periodically when active or returning from background
  // The caller might want to call checkSlowmode after sending a message
  return {
    remainingSeconds,
    checkSlowmode,
  };
}