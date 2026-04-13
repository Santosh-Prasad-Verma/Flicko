/**
 * Logging and Monitoring Utilities
 * 
 * Provides centralized logging with different severity levels.
 * Can be hooked up to external monitoring services (DataDog, Sentry, etc.).
 * 
 * Requirements: 22.1, 22.2, 22.3
 */

export enum LogLevel {
    DEBUG = 0,
    INFO = 1,
    WARN = 2,
    ERROR = 3,
}

// Ensure the environment variable controls console output level
// Default to INFO in production, DEBUG in development
const currentLogLevel = import.meta.env?.PROD ? LogLevel.INFO : LogLevel.DEBUG;

export const logger = {
    debug: (message: string, context?: any) => {
        if (currentLogLevel <= LogLevel.DEBUG) {
            console.debug(`[DEBUG] ${message}`, context || '');
        }
    },

    info: (message: string, context?: any) => {
        if (currentLogLevel <= LogLevel.INFO) {
            console.info(`[INFO]  ${message}`, context || '');
        }
    },

    warn: (message: string, context?: any) => {
        if (currentLogLevel <= LogLevel.WARN) {
            console.warn(`[WARN]  ${message}`, context || '');
            // Ideally ship this to a monitoring service
        }
    },

    error: (message: string, error?: any, context?: any) => {
        if (currentLogLevel <= LogLevel.ERROR) {
            console.error(`[ERROR] ${message}`, error || '', context || '');
            // Send error to Sentry or similar observability platform
            reportErrorToMonitoring(message, error, context);
        }
    },
};

/**
 * Stub function for reporting errors to an external monitoring service
 */
function reportErrorToMonitoring(_message: string, _error?: any, _context?: any) {
    // e.g., Sentry.captureException(error, { extra: context })
    // In a real implementation this would be hooked up to a tracking SDK
}
