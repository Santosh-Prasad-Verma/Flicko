/**
 * Safe navigation utilities for Expo Router
 * 
 * Provides safe navigation methods that handle edge cases like:
 * - Deep link entry (no navigation history)
 * - First screen in stack
 * - Navigation state resets
 */

import { Router } from 'expo-router';

/**
 * Safely navigate back with fallback route
 * 
 * Checks if navigation history exists before calling router.back().
 * If no history exists, navigates to the fallback route instead.
 * 
 * @param router - Expo Router instance
 * @param fallbackRoute - Route to navigate to if back is not possible (default: '/(tabs)')
 * 
 * @example
 * ```tsx
 * import { router } from 'expo-router';
 * import { safeGoBack } from '@/utils/navigation';
 * 
 * // In a settings screen
 * <Button onPress={() => safeGoBack(router, '/(tabs)')} title="Back" />
 * ```
 */
export function safeGoBack(router: Router, fallbackRoute: string = '/(tabs)') {
  try {
    // Check if we can go back by checking if canGoBack exists
    // Expo Router doesn't have a built-in canGoBack method, so we try to go back
    // and catch any errors
    if (canGoBack(router)) {
      router.back();
    } else {
      // No history, navigate to fallback
      router.replace(fallbackRoute as any);
    }
  } catch (error) {
    // If back() throws an error, navigate to fallback
    console.warn('[safeGoBack] Navigation back failed, using fallback:', error);
    router.replace(fallbackRoute as any);
  }
}

/**
 * Check if router can go back
 * 
 * This is a workaround since Expo Router doesn't expose canGoBack directly.
 * We check the navigation state to determine if there's history.
 * 
 * @param router - Expo Router instance
 * @returns true if navigation can go back, false otherwise
 */
function canGoBack(router: Router): boolean {
  try {
    // Access the navigation state through the router
    // This is a heuristic - if we're at the root, we can't go back
    const state = (router as any).state;
    
    if (!state) {
      return false;
    }
    
    // Check if there's navigation history
    // The state should have a routes array with more than 1 item
    if (state.routes && Array.isArray(state.routes)) {
      return state.routes.length > 1;
    }
    
    // If we can't determine, assume we can't go back (safer)
    return false;
  } catch {
    // If anything fails, assume we can't go back
    return false;
  }
}

/**
 * Safe dismiss for modal screens
 * 
 * Attempts to dismiss the modal, falls back to navigation if dismiss fails.
 * 
 * @param router - Expo Router instance
 * @param fallbackRoute - Route to navigate to if dismiss fails
 */
export function safeDismiss(router: Router, fallbackRoute: string = '/(tabs)') {
  try {
    if (router.canDismiss && router.canDismiss()) {
      router.dismiss();
    } else {
      router.replace(fallbackRoute as any);
    }
  } catch (error) {
    console.warn('[safeDismiss] Dismiss failed, using fallback:', error);
    router.replace(fallbackRoute as any);
  }
}
