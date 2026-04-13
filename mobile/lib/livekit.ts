/**
 * LiveKit Initialization Module
 *
 * MUST be imported at the very top of the app entry point (before any LiveKit usage).
 * Registers WebRTC globals and configures the audio session for voice/video calls.
 *
 * NOTE: Wrapped in try-catch so the app can still run in Expo Go
 * (where native WebRTC modules are unavailable). LiveKit features
 * will only work in a custom development build.
 */
import { Platform, AppState, AppStateStatus } from 'react-native';

let _AudioSession: typeof import('@livekit/react-native').AudioSession | null = null;
let _liveKitAvailable = false;
let _isSessionActive = false;

try {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const lk = require('@livekit/react-native');
  lk.registerGlobals();
  _AudioSession = lk.AudioSession;
  _liveKitAvailable = true;
  console.log('[LiveKit] Native modules loaded & globals registered');
} catch (err) {
  console.warn('[LiveKit] Native modules not available (Expo Go?). Voice/video features disabled.', (err as Error).message);
}

/**
 * Configure the audio session for voice/video calls.
 * Call this once at app startup.
 */
export async function configureAudioSession(): Promise<void> {
  if (!_liveKitAvailable || !_AudioSession) return;
  try {
    if (Platform.OS === 'ios') {
      await _AudioSession.setAppleAudioConfiguration({
        audioCategory: 'playAndRecord',
        audioCategoryOptions: [
          'allowBluetooth',
          'allowBluetoothA2DP',
          'defaultToSpeaker',
          'mixWithOthers',
        ],
        audioMode: 'videoChat',
      });
    } else if (Platform.OS === 'android') {
      await _AudioSession.configureAudio({
        android: {
          audioTypeOptions: {
            manageAudioFocus: true,
            audioMode: 'inCommunication',
            audioStreamType: 'voiceCall',
            audioFocusMode: 'gain',
          },
        },
      });
    }

    console.log('[LiveKit] Audio session configured');
  } catch (err) {
    console.warn('[LiveKit] Audio session config failed (non-fatal):', err);
  }
}

/**
 * Start the audio session (call when joining a voice channel).
 */
export async function startAudioSession(): Promise<void> {
  if (!_liveKitAvailable || !_AudioSession) return;
  try {
    await _AudioSession.startAudioSession();
    _isSessionActive = true;
    console.log('[LiveKit] Audio session started');
  } catch (err) {
    console.warn('[LiveKit] Failed to start audio session:', err);
  }
}

/**
 * Stop the audio session (call when leaving a voice channel).
 */
export async function stopAudioSession(): Promise<void> {
  if (!_liveKitAvailable || !_AudioSession) return;
  try {
    await _AudioSession.stopAudioSession();
    _isSessionActive = false;
    console.log('[LiveKit] Audio session stopped');
  } catch (err) {
    console.warn('[LiveKit] Failed to stop audio session:', err);
  }
}

// OS AppState Listener to gracefully manage audio when app goes to background
if (Platform.OS === 'ios' || Platform.OS === 'android') {
  let appState: AppStateStatus = AppState.currentState;

  AppState.addEventListener('change', async (nextAppState) => {
    // If the app goes to the background or becomes inactive, stop audio session gracefully
    if (appState.match(/active/) && (nextAppState === 'background' || nextAppState === 'inactive')) {
      if (_isSessionActive && _AudioSession) {
        console.log('[LiveKit] App backgrounded, stopping audio session momentarily to free resources');
        _isSessionActive = true; // Save the intent so we know to resume
        await _AudioSession.stopAudioSession().catch(e => console.warn('LiveKit bg stop error', e));
      }
    } 
    // If the app comes back to the foreground and had an active session, restart it
    else if (appState.match(/inactive|background/) && nextAppState === 'active') {
      if (_isSessionActive && _AudioSession) {
        console.log('[LiveKit] App returned to active, restarting audio session');
        await _AudioSession.startAudioSession().catch(e => console.warn('LiveKit active start error', e));
      }
    }
    appState = nextAppState;
  });
}

export const isLiveKitAvailable = _liveKitAvailable;
export const LIVEKIT_URL = process.env.EXPO_PUBLIC_LIVEKIT_URL || 'wss://flicko-nnuau2un.livekit.cloud';
