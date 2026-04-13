/**
 * Flicko Typography System — Discord GG Sans
 *
 * Font families must match the keys used in useFonts() in _layout.tsx.
 * Available weights: Regular (400), Medium (500), SemiBold (600), Bold (700).
 */

// ─── FONT FAMILY NAMES ───
// These must match the keys used in useFonts() exactly
export const FontFamily = {
    regular:    'gg-sans',
    medium:     'gg-sans-medium',
    semibold:   'gg-sans-semibold',
    bold:       'gg-sans-bold',
    mono:       'monospace',
} as const;


// ─── TYPOGRAPHY STYLES ───
// Matching Discord's exact text hierarchy
export const Typography = {

    // ─── HEADINGS ───
    // Server name in sidebar, screen titles, modal titles
    heading: {
        xl: {
            fontFamily: FontFamily.bold,
            fontSize: 24,
            lineHeight: 30,
            letterSpacing: -0.3,
        },
        lg: {
            fontFamily: FontFamily.bold,
            fontSize: 20,
            lineHeight: 26,
            letterSpacing: -0.2,
        },
        md: {
            fontFamily: FontFamily.semibold,
            fontSize: 17,
            lineHeight: 22,
        },
        sm: {
            fontFamily: FontFamily.semibold,
            fontSize: 15,
            lineHeight: 20,
        },
    },

    // ─── BODY TEXT ───
    // Chat messages, descriptions, info text
    body: {
        lg: {
            fontFamily: FontFamily.regular,
            fontSize: 16,
            lineHeight: 22,
        },
        md: {
            fontFamily: FontFamily.regular,
            fontSize: 15,
            lineHeight: 20,
        },
        sm: {
            fontFamily: FontFamily.regular,
            fontSize: 13,
            lineHeight: 18,
        },
        xs: {
            fontFamily: FontFamily.regular,
            fontSize: 12,
            lineHeight: 16,
        },
    },

    // ─── LABELS ───
    // Channel names, timestamps, member counts, buttons
    label: {
        lg: {
            fontFamily: FontFamily.medium,
            fontSize: 16,
            lineHeight: 20,
        },
        md: {
            fontFamily: FontFamily.medium,
            fontSize: 14,
            lineHeight: 18,
        },
        sm: {
            fontFamily: FontFamily.medium,
            fontSize: 12,
            lineHeight: 16,
            letterSpacing: 0.3,
        },
        xs: {
            fontFamily: FontFamily.semibold,
            fontSize: 11,
            lineHeight: 14,
            letterSpacing: 0.5,
            textTransform: 'uppercase' as const,
        },
    },

    // ─── CHAT SPECIFIC ───
    // Exact Discord message styles
    chat: {
        // Message author name
        username: {
            fontFamily: FontFamily.medium,
            fontSize: 16,
            lineHeight: 20,
        },
        // Message text
        message: {
            fontFamily: FontFamily.regular,
            fontSize: 16,
            lineHeight: 22,
        },
        // Reply preview text
        reply: {
            fontFamily: FontFamily.regular,
            fontSize: 14,
            lineHeight: 18,
        },
        // Timestamp next to username
        timestamp: {
            fontFamily: FontFamily.medium,
            fontSize: 12,
            lineHeight: 16,
        },
        // System messages (user joined, pinned message, etc.)
        system: {
            fontFamily: FontFamily.regular,
            fontSize: 15,
            lineHeight: 20,
        },
    },

    // ─── CHANNEL LIST ───
    channel: {
        // CATEGORY NAME (uppercase)
        category: {
            fontFamily: FontFamily.semibold,
            fontSize: 12,
            lineHeight: 16,
            letterSpacing: 0.5,
            textTransform: 'uppercase' as const,
        },
        // #channel-name
        name: {
            fontFamily: FontFamily.medium,
            fontSize: 16,
            lineHeight: 20,
        },
        // Channel topic/description
        topic: {
            fontFamily: FontFamily.regular,
            fontSize: 12,
            lineHeight: 16,
        },
    },

    // ─── CODE ───
    // Code blocks and inline code in messages
    code: {
        block: {
            fontFamily: FontFamily.mono,
            fontSize: 14,
            lineHeight: 20,
        },
        inline: {
            fontFamily: FontFamily.mono,
            fontSize: 13.5,
            lineHeight: 18,
        },
    },

    // ─── BUTTONS ───
    button: {
        lg: {
            fontFamily: FontFamily.medium,
            fontSize: 16,
            lineHeight: 20,
        },
        md: {
            fontFamily: FontFamily.medium,
            fontSize: 14,
            lineHeight: 18,
        },
        sm: {
            fontFamily: FontFamily.medium,
            fontSize: 13,
            lineHeight: 16,
        },
    },

    // ─── INPUT ───
    input: {
        text: {
            fontFamily: FontFamily.regular,
            fontSize: 16,
            lineHeight: 22,
        },
        placeholder: {
            fontFamily: FontFamily.regular,
            fontSize: 16,
            lineHeight: 22,
        },
    },
} as const;
