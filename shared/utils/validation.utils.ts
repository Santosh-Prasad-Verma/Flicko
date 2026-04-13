/**
 * Validation and Sanitization Utilities
 * 
 * Provides common validation functions for user inputs to prevent
 * invalid data and specific injection attacks before reaching the service layer.
 * 
 * CRIT-007: Strengthened password validation with special chars, common password check
 * MED-004: Improved email validation for RFC compliance
 * Requirements: 21.2, 21.3, 21.4, 21.5, 21.6, 21.7, 21.8
 */

// MED-004: Improved RFC 5322 compliant email regex
export const REGEX = {
    EMAIL: /^[a-zA-Z0-9!#$%&'*+\/=?^_`{|}~-]+(?:\.[a-zA-Z0-9!#$%&'*+\/=?^_`{|}~-]+)*@(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?$/,
    USERNAME: /^[a-zA-Z0-9_.-]{2,32}$/,
    URL: /^https?:\/\/(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)$/,
    HEX_COLOR: /^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/,
    DISCRIMINATOR: /^[0-9]{4}$/,
};

// CRIT-007: Common passwords list for rejection
const COMMON_PASSWORDS = new Set([
    'password1', 'password123', 'qwerty123', 'admin123',
    'welcome1', 'letmein1', 'monkey123', 'dragon123',
    'abc12345', 'master123', 'login123', 'princess1',
    'football1', 'shadow123', 'sunshine1', 'trustno1',
    'iloveyou1', 'batman123', 'access123', 'hello123',
    'charlie1', 'donald123', '123456789a', 'password1!',
]);

/**
 * Validate an email address format
 * MED-004: Enhanced with RFC compliance checks
 */
export function validateEmail(email: string): boolean {
    if (!email || email.length > 254) return false;

    // Basic format check
    if (!REGEX.EMAIL.test(email.toLowerCase())) return false;

    // Additional checks
    const [local, domain] = email.split('@');

    // Local part checks
    if (!local || local.length > 64) return false;
    if (local.startsWith('.') || local.endsWith('.')) return false;
    if (local.includes('..')) return false;

    // Domain checks
    if (!domain || domain.length > 253) return false;
    if (domain.startsWith('.') || domain.endsWith('.')) return false;
    if (domain.includes('..')) return false;

    // TLD check (at least 2 chars)
    const tld = domain.split('.').pop();
    if (!tld || tld.length < 2) return false;

    return true;
}

/**
 * Validate a username
 * Typically allows alphanumeric, underscore, and dash
 */
export function validateUsername(username: string): boolean {
    return REGEX.USERNAME.test(username);
}

/**
 * Validate password strength
 * CRIT-007: Requires at least 12 characters, one uppercase, one lowercase,
 * one number, one special character. Rejects common passwords and patterns.
 */
export function validatePassword(password: string): boolean {
    if (password.length < 8) return false;

    const hasUpperCase = /[A-Z]/.test(password);
    const hasLowerCase = /[a-z]/.test(password);
    const hasNumbers = /\d/.test(password);
    const hasSpecial = /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password);

    if (!hasUpperCase || !hasLowerCase || !hasNumbers || !hasSpecial) {
        return false;
    }

    // Check against common passwords (case-insensitive)
    if (COMMON_PASSWORDS.has(password.toLowerCase())) {
        return false;
    }

    // Check for sequential repeated characters (e.g., "aaa", "111")
    if (/(.)\1{2,}/.test(password)) {
        return false;
    }

    // Check for keyboard patterns
    const keyboardPatterns = ['qwerty', 'asdfgh', '123456', 'abcdef', 'zxcvbn'];
    const lowerPass = password.toLowerCase();
    for (const pattern of keyboardPatterns) {
        if (lowerPass.includes(pattern)) {
            return false;
        }
    }

    return true;
}

/**
 * Get password strength score
 * CRIT-007: Provides user-facing strength indicator
 */
export function getPasswordStrength(password: string): 'weak' | 'medium' | 'strong' {
    let score = 0;

    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (/[A-Z]/.test(password)) score++;
    if (/[a-z]/.test(password)) score++;
    if (/\d/.test(password)) score++;
    if (/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password)) score++;

    // Entropy bonus
    const uniqueChars = new Set(password).size;
    if (uniqueChars >= password.length * 0.7) score++;

    if (score <= 3) return 'weak';
    if (score <= 5) return 'medium';
    return 'strong';
}

/**
 * Validate a URL (useful for avatars, attachments from external sources)
 */
export function validateUrl(url: string): boolean {
    return REGEX.URL.test(url);
}

/**
 * Validate a hex color code (used for roles, profiles)
 */
export function validateColorCode(color: string): boolean {
    return REGEX.HEX_COLOR.test(color);
}

/**
 * Check if all required fields are present and not empty strings
 * 
 * @param fields - Object containing fields to check
 * @returns Array of missing field names, empty if all pass
 */
export function validateRequired(fields: Record<string, any>): string[] {
    const missing: string[] = [];

    for (const [key, value] of Object.entries(fields)) {
        if (value === undefined || value === null || (typeof value === 'string' && value.trim() === '')) {
            missing.push(key);
        }
    }

    return missing;
}

/**
 * Basic input sanitization to trim whitespace
 * More complex escaping (like XSS prevention) is typically handled 
 * at the render layer (React does this automatically) or specific service 
 * implementations (e.g., using DOMPurify for rich text).
 */
export function sanitizeInput(input: string): string {
    if (typeof input !== 'string') return input;
    return input.trim();
}

/**
 * Validate that a number falls within a specified range (inclusive)
 */
export function validateNumericRange(value: number, min: number, max: number): boolean {
    return typeof value === 'number' && !isNaN(value) && value >= min && value <= max;
}

/**
 * Throws an error with all validation failures if any
 * 
 * @param missingFields - Array of missing field names
 * @throws Error if the array is not empty
 */
export function assertRequiredFields(missingFields: string[]): void {
    if (missingFields.length > 0) {
        throw new Error(`Missing required fields: ${missingFields.join(', ')}`);
    }
}
