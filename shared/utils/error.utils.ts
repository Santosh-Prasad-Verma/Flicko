/**
 * Error Handling Utilities
 * 
 * Provides consistent error formatting, mapping for Supabase error codes,
 * and retry logic for transient failures.
 * 
 * Requirements: 2.3, 20.1, 20.4
 */

export interface AppError {
    code: string;
    message: string;
    details?: any;
    statusCode: number;
}

/**
 * Maps Supabase PostgreSQL error codes to user-friendly application errors
 * 
 * @param error - The error object from Supabase
 * @returns A standardized AppError object
 */
export function handleSupabaseError(error: any): AppError {
    // Default fallback error
    const appError: AppError = {
        code: 'UNKNOWN_ERROR',
        message: 'An unexpected error occurred. Please try again later.',
        details: error,
        statusCode: 500,
    };

    if (!error) return appError;

    // Supabase/PostgREST specific error codes
    if (error.code) {
        switch (error.code) {
            case '23505': // unique_violation
                appError.code = 'CONFLICT';
                appError.message = 'A record with this information already exists.';
                appError.statusCode = 409;

                // Try to parse which field violated the constraint
                if (error.message.includes('username')) {
                    appError.message = 'This username is already taken.';
                } else if (error.message.includes('email')) {
                    appError.message = 'An account with this email already exists.';
                }
                break;

            case '23503': // foreign_key_violation
                appError.code = 'NOT_FOUND';
                appError.message = 'The referenced record does not exist.';
                appError.statusCode = 404;
                break;

            case '42501': // insufficient_privilege
            case 'PGRST301': // JWT missing or invalid
                appError.code = 'UNAUTHORIZED';
                appError.message = 'You do not have permission to perform this action.';
                appError.statusCode = 403;
                break;

            case '22P02': // invalid_text_representation (e.g., bad UUID)
                appError.code = 'BAD_REQUEST';
                appError.message = 'Invalid ID format provided.';
                appError.statusCode = 400;
                break;
        }
    }

    // Auth specific errors
    if (error.status) {
        appError.statusCode = error.status;
    }

    if (error.name === 'AuthApiError' || error.name === 'AuthSessionMissingError') {
        appError.code = 'AUTH_ERROR';
        appError.message = error.message;
        if (appError.statusCode === 500) {
            appError.statusCode = 401; // Default to unauthorized for auth errors if not specified
        }
    }

    // Use the provided message if it's already a standard Error object without a specific Postgres code
    if (error instanceof Error && !error.message.includes('relation "')) {
        if (appError.code === 'UNKNOWN_ERROR') {
            appError.message = error.message;
            appError.statusCode = 400;
        }
    }

    return appError;
}

/**
 * Automatically retry a failed asynchronous operation with exponential backoff
 * 
 * @param operation - The async function to execute
 * @param maxRetries - Maximum number of retry attempts (default: 3)
 * @param baseDelayMs - Base delay in milliseconds before first retry (default: 1000)
 * @returns The result of the operation
 * @throws The last error encountered if all retries fail
 */
export async function withRetry<T>(
    operation: () => Promise<T>,
    maxRetries: number = 3,
    baseDelayMs: number = 1000
): Promise<T> {
    let lastError: any;

    for (let attempt = 0; attempt <= maxRetries; attempt++) {
        try {
            return await operation();
        } catch (error: any) {
            lastError = error;

            // Don't retry if it's a client error (4xx) or authentication issue
            const isClientError = error.status && error.status >= 400 && error.status < 500;
            const isAuthError = error.name === 'AuthApiError' || error.name === 'AuthSessionMissingError';

            // Only retry on network errors, 5xx server errors, or timeouts
            if (attempt === maxRetries || isClientError || isAuthError) {
                throw error;
            }

            // Calculate delay with exponential backoff and a little jitter
            const delay = (baseDelayMs * Math.pow(2, attempt)) + (Math.random() * 100);

            console.warn(`Operation failed, retrying in ${Math.round(delay)}ms (Attempt ${attempt + 1}/${maxRetries})...`);

            // Wait before next attempt
            await new Promise(resolve => setTimeout(resolve, delay));
        }
    }

    throw lastError;
}
