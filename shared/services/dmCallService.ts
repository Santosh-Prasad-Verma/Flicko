import { supabase } from '../lib/supabase';
import { mediaService } from './mediaService';
import { useDMCallStore, type DMCall, type CallType } from '../stores/dmCallStore';

export async function initiateCall(
  dmId: string,
  calleeId: string,
  callType: CallType
): Promise<void> {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) throw new Error('Not authenticated');

  const roomName = `dm_${dmId}_${Date.now()}`;

  // Create call record
  const { data: call, error } = await supabase
    .from('dm_calls')
    .insert({
      dm_id: dmId,
      caller_id: session.user.id,
      callee_id: calleeId,
      call_type: callType,
      status: 'ringing',
      room_name: roomName,
      started_at: new Date().toISOString(),
    })
    .select()
    .single();

  if (error) throw error;

  useDMCallStore.getState().setCurrentCall({
    id: call.id,
    dmId: call.dm_id,
    callerId: call.caller_id,
    calleeId: call.callee_id,
    status: call.status,
    callType: call.call_type,
    roomName: call.room_name,
    startedAt: call.started_at,
  });

  // Join LiveKit Room
  await mediaService.joinChannel({
    channelId: dmId,
    serverId: 'dm',
    enableVideo: callType === 'video',
  });

  // Send push notification to recipient
  try {
    await supabase.functions.invoke('push-notify', {
      body: {
        type: 'call',
        dm_id: dmId,
        call_id: call.id,
        caller_id: session.user.id,
        call_type: callType,
      },
    });
  } catch (e) {
    console.warn('[dmCallService] Push notification failed:', e);
  }
}

export async function answerCall(call: DMCall): Promise<void> {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) throw new Error('Not authenticated');

  // Update call status
  await supabase
    .from('dm_calls')
    .update({ status: 'accepted', answered_at: new Date().toISOString() })
    .eq('id', call.id);

  useDMCallStore.getState().setCurrentCall({ ...call, status: 'accepted' });

  // Join LiveKit Room
  await mediaService.joinChannel({
    channelId: call.dmId,
    serverId: 'dm',
    enableVideo: call.callType === 'video',
  });
}

export async function declineCall(callId: string): Promise<void> {
  await supabase
    .from('dm_calls')
    .update({ status: 'rejected', ended_at: new Date().toISOString() })
    .eq('id', callId);
  
  useDMCallStore.getState().resetCall();
}

export async function endCall(callId: string): Promise<void> {
  await supabase
    .from('dm_calls')
    .update({ status: 'ended', ended_at: new Date().toISOString() })
    .eq('id', callId);

  await mediaService.leaveChannel();
  useDMCallStore.getState().resetCall();
}

export function subscribeToCalls(userId: string): () => void {
  const channel = supabase
    .channel(`dm_calls:${userId}`)
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'dm_calls',
        filter: `callee_id=eq.${userId}`,
      },
      async (payload) => {
        const newCall = payload.new as any;
        if (newCall.status === 'ringing') {
          // Fetch caller profile
          const { data: profile } = await supabase
            .from('profiles')
            .select('username, avatar:avatar_url')
            .eq('id', newCall.caller_id)
            .single();

          useDMCallStore.getState().setIncomingCall({
            id: newCall.id,
            dmId: newCall.dm_id,
            callerId: newCall.caller_id,
            calleeId: newCall.callee_id,
            status: newCall.status,
            callType: newCall.call_type,
            roomName: newCall.room_name,
            startedAt: newCall.started_at,
            callerProfile: profile ? {
              username: profile.username,
              avatarUrl: profile.avatar,
            } : undefined,
          });
        }
      }
    )
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'dm_calls',
      },
      (payload) => {
        const updatedCall = payload.new as any;
        const currentCall = useDMCallStore.getState().currentCall;
        const incomingCall = useDMCallStore.getState().incomingCall;

        // If the call we're in or the one ringing us was ended/rejected
        if ((currentCall?.id === updatedCall.id || incomingCall?.id === updatedCall.id) && 
            (updatedCall.status === 'ended' || updatedCall.status === 'rejected')) {
          useDMCallStore.getState().resetCall();
        }
      }
    )
    .subscribe();

  return () => {
    supabase.removeChannel(channel);
  };
}
