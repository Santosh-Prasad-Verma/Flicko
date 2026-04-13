/**
 * Rate Limiting Utilities
 * 
 * Provides client-side throttling to prevent spamming the Supabase API.
 * Note: Real rate limiting must also be enforced via Supabase Edge Functions or RLS triggers.
 * 
 * Requirements: 19.1, 19.2
 */

interface RateLimitEntry {
    count: number;
    resetTime: number;
}

const rateLimits = new Map<string, RateLimitEntry>();

/**
 * Check if an action is currently rate limited
 * 
 * @param actionId - Unique identifier for the action (e.g. 'sendMessage:channel_123')
 * @param maxRequests - Maximum allowed requests in the window
 * @param windowMs - Time window in milliseconds (e.g. 60000 for 1 minute)
 * @returns boolean indicating if the action is allowed
 */
export function checkRateLimit(actionId: string, maxRequests: number, windowMs: number): boolean {
    const now = Date.now();
    const entry = rateLimits.get(actionId);

    // If entry exists and we're within the window
    if (entry && now < entry.resetTime) {
        if (entry.count >= maxRequests) {
            return false; // Rate limited
        }
        // Increment count
        entry.count += 1;
        return true; // Allowed
    }

    // Create new entry or reset expired entry
    rateLimits.set(actionId, {
        count: 1,
        resetTime: now + windowMs,
    });

    return true; // Allowed
}

/**
 * Utility decorator/wrapper to automatically apply rate limiting to a function
 * 
 * @param fn - The function to rate limit
 * @param actionId - Unique identifier for the action
 * @param maxRequests - Maximum allowed requests in the window
 * @param windowMs - Time window in milliseconds
 * @returns Wrapped function that throws if rate limited
 */
export function withRateLimit<T extends (...args: any[]) => Promise<any>>(
    fn: T,
    actionId: string,
    maxRequests: number,
    windowMs: number
): (...args: Parameters<T>) => ReturnType<T> {
    return (async (...args: Parameters<T>) => {
        if (!checkRateLimit(actionId, maxRequests, windowMs)) {
            throw new Error(`Rate limit exceeded for action: ${actionId}. Please try again later.`);
        }
        return fn(...args);
    }) as (...args: Parameters<T>) => ReturnType<T>;
}
