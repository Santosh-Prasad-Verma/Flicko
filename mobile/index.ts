// Crypto polyfills MUST be the first import — uuid (used by @aws-sdk)
// captures crypto.getRandomValues at module evaluation time, so it must
// be available before the app tree loads.
import './polyfills';

// LiveKit: register WebRTC globals BEFORE any component renders
import './lib/livekit';

import 'expo-router/entry';
