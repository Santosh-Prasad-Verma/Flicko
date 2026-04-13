/**
 * Timestamp Utilities
 *
 * Discord-style timestamp formatting: relative, absolute, date, time.
 * Supports <t:EPOCH:STYLE> syntax.
 * Requirements: Feature 30 (Timestamps)
 */

export type TimestampStyle = 't' | 'T' | 'd' | 'D' | 'f' | 'F' | 'R';

const STYLE_LABELS: Record<TimestampStyle, string> = {
  t: 'Short Time',       // 4:20 PM
  T: 'Long Time',        // 4:20:30 PM
  d: 'Short Date',       // 02/26/2026
  D: 'Long Date',        // February 26, 2026
  f: 'Short Date/Time',  // February 26, 2026 4:20 PM
  F: 'Long Date/Time',   // Thursday, February 26, 2026 4:20 PM
  R: 'Relative Time',    // 2 hours ago
};

/**
 * Parse Discord-style timestamp tokens: <t:1234567890:R>
 * Returns array of { epoch, style, raw } found in text.
 */
export function parseTimestamps(text: string): { epoch: number; style: TimestampStyle; raw: string; index: number }[] {
  const regex = /<t:(\d+)(?::([tTdDfFR]))?>/g;
  const results: { epoch: number; style: TimestampStyle; raw: string; index: number }[] = [];
  let match: RegExpExecArray | null;

  while ((match = regex.exec(text)) !== null) {
    results.push({
      epoch: parseInt(match[1], 10),
      style: (match[2] as TimestampStyle) || 'f',
      raw: match[0],
      index: match.index,
    });
  }

  return results;
}

/**
 * Format a Unix epoch timestamp with a given style.
 */
export function formatTimestamp(epoch: number, style: TimestampStyle = 'f'): string {
  const date = new Date(epoch * 1000);

  switch (style) {
    case 't': // Short Time: 4:20 PM
      return date.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
    case 'T': // Long Time: 4:20:30 PM
      return date.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit', second: '2-digit' });
    case 'd': // Short Date: 02/26/2026
      return date.toLocaleDateString(undefined, { month: '2-digit', day: '2-digit', year: 'numeric' });
    case 'D': // Long Date: February 26, 2026
      return date.toLocaleDateString(undefined, { month: 'long', day: 'numeric', year: 'numeric' });
    case 'f': // Short Date/Time
      return date.toLocaleDateString(undefined, { month: 'long', day: 'numeric', year: 'numeric' }) + ' ' +
             date.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
    case 'F': // Long Date/Time
      return date.toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' }) + ' ' +
             date.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
    case 'R': // Relative
      return formatRelativeTime(date);
    default:
      return date.toLocaleString();
  }
}

/**
 * Format a relative time string (e.g., "2 hours ago", "in 3 days").
 */
export function formatRelativeTime(date: Date): string {
  const now = Date.now();
  const diff = now - date.getTime();
  const absDiff = Math.abs(diff);
  const future = diff < 0;

  const seconds = Math.floor(absDiff / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);
  const months = Math.floor(days / 30);
  const years = Math.floor(days / 365);

  let unit: string;
  let value: number;

  if (seconds < 60) { unit = 'second'; value = seconds; }
  else if (minutes < 60) { unit = 'minute'; value = minutes; }
  else if (hours < 24) { unit = 'hour'; value = hours; }
  else if (days < 30) { unit = 'day'; value = days; }
  else if (months < 12) { unit = 'month'; value = months; }
  else { unit = 'year'; value = years; }

  const plural = value !== 1 ? 's' : '';
  return future ? `in ${value} ${unit}${plural}` : `${value} ${unit}${plural} ago`;
}

/**
 * Format a chat message timestamp (compact).
 */
export function formatMessageTime(iso: string): string {
  const date = new Date(iso);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();

  // Today
  if (date.toDateString() === now.toDateString()) {
    return 'Today at ' + date.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
  }

  // Yesterday
  const yesterday = new Date(now);
  yesterday.setDate(yesterday.getDate() - 1);
  if (date.toDateString() === yesterday.toDateString()) {
    return 'Yesterday at ' + date.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
  }

  // Within a week
  if (diffMs < 7 * 24 * 60 * 60 * 1000) {
    return date.toLocaleDateString(undefined, { weekday: 'long' }) + ' at ' +
           date.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
  }

  // Older
  return date.toLocaleDateString(undefined, { month: '2-digit', day: '2-digit', year: 'numeric' });
}

/**
 * Create a Discord-style timestamp string for embedding.
 */
export function createTimestampToken(date: Date, style: TimestampStyle = 'R'): string {
  return `<t:${Math.floor(date.getTime() / 1000)}:${style}>`;
}

export { STYLE_LABELS };
