/**
 * Crash Reporting & Error Tracking Service
 *
 * MED-001: Centralized crash reporting abstraction.
 * Currently wraps Sentry, but the interface is provider-agnostic
 * so you can swap to Firebase Crashlytics or another provider.
 *
 * Setup:
 *   1. `npx expo install @sentry/react-native`
 *   2. Set SENTRY_DSN in your environment / app.json extra
 *   3. Call `initCrashReporting()` in your root layout before rendering
 *
 * Until @sentry/react-native is installed, all methods are safe no-ops.
 */

let _sentry: any = null;
let _initialized = false;

/**
 * Initialize Sentry crash reporting.
 * Safe to call even if @sentry/react-native is not installed (no-op).
 */
export function initCrashReporting(dsn?: string): void {
  if (_initialized) return;

  try {
    // Dynamic import so the app doesn't crash if Sentry isn't installed
    _sentry = require('@sentry/react-native');
    _sentry.init({
      dsn: dsn || process.env.SENTRY_DSN || process.env.EXPO_PUBLIC_SENTRY_DSN || '',
      debug: __DEV__,
      enabled: !__DEV__, // Only report in production
      tracesSampleRate: 0.2, // 20% of transactions for performance monitoring
      environment: __DEV__ ? 'development' : 'production',
      // Attach user context automatically from auth store
      beforeSend(event: any) {
        // Strip any PII from breadcrumbs if needed
        return event;
      },
    });
    _initialized = true;
    console.log('[CrashReporting] Sentry initialized');
  } catch (e) {
    // @sentry/react-native not installed — silent no-op
    console.log('[CrashReporting] Sentry not available, crash reporting disabled');
    _initialized = true;
  }
}

/**
 * Report a caught exception to Sentry.
 */
export function captureException(error: Error | unknown, context?: Record<string, any>): void {
  if (_sentry) {
    if (context) {
      _sentry.withScope((scope: any) => {
        Object.entries(context).forEach(([key, value]) => {
          scope.setExtra(key, value);
        });
        _sentry.captureException(error);
      });
    } else {
      _sentry.captureException(error);
    }
  } else {
    console.error('[CrashReporting] Unhandled error:', error);
  }
}

/**
 * Log a breadcrumb for debugging context.
 */
export function addBreadcrumb(
  message: string,
  category?: string,
  data?: Record<string, any>,
): void {
  if (_sentry) {
    _sentry.addBreadcrumb({
      message,
      category: category || 'app',
      data,
      level: 'info',
    });
  }
}

/**
 * Set user context for crash reports.
 * Call after login / auth state change.
 */
export function setUser(user: { id: string; username?: string; email?: string } | null): void {
  if (_sentry) {
    _sentry.setUser(
      user
        ? { id: user.id, username: user.username, email: user.email }
        : null,
    );
  }
}

/**
 * Wrap a React component tree with Sentry's error boundary.
 * Returns the component as-is if Sentry is not available.
 */
export function wrapWithSentry<T extends React.ComponentType<any>>(component: T): T {
  if (_sentry?.wrap) {
    return _sentry.wrap(component);
  }
  return component;
}
