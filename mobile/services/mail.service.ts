/**
 * Mail Gateway Service
 *
 * Sends requests to the Flicko mail-gateway (Go service) that handles
 * email rendering and SMTP delivery. Used to trigger welcome emails
 * after signup and other transactional emails the frontend controls.
 *
 * The mail gateway runs at MAIL_GATEWAY_URL (default: http://localhost:8080).
 */
import { Platform } from 'react-native';
import Constants from 'expo-constants';
import { MAIL_GATEWAY_URL, MAIL_GATEWAY_API_KEY } from '../constants/Config';

interface SendEmailParams {
  /** Recipient email address */
  to: string;
  /** Email type: "welcome" (more types can be added) */
  type: 'welcome';
  /** Display name shown in the email (falls back to email) */
  username?: string;
  /** Profile picture URL */
  avatarUrl?: string;
}

let hasLoggedGatewayUnavailableInDev = false;

function normalizeBaseUrl(url: string): string {
  return url.trim().replace(/\/+$/, '');
}

function getCandidateGatewayUrls(): string[] {
  const candidates: string[] = [];

  if (MAIL_GATEWAY_URL) {
    candidates.push(normalizeBaseUrl(MAIL_GATEWAY_URL));
  }

  const expoHostUri = (Constants.expoConfig as any)?.hostUri as string | undefined;
  const expoHost = expoHostUri?.split(':')?.[0];
  if (expoHost) {
    candidates.push(`http://${expoHost}:8080`);
  }

  if (Platform.OS === 'android') {
    candidates.push('http://10.0.2.2:8080');
  }

  candidates.push('http://127.0.0.1:8080');
  candidates.push('http://localhost:8080');

  return [...new Set(candidates.map(normalizeBaseUrl))];
}

/**
 * Send a transactional email via the mail gateway.
 *
 * POST {MAIL_GATEWAY_URL}/send
 * Header: x-api-key (if configured)
 * Body: { to, type, username?, avatar_url? }
 *
 * This is fire-and-forget — errors are logged but not thrown,
 * because a failed welcome email should never block signup.
 */
export async function sendEmail(params: SendEmailParams): Promise<boolean> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };

  if (MAIL_GATEWAY_API_KEY) {
    headers['x-api-key'] = MAIL_GATEWAY_API_KEY;
  }

  const gatewayUrls = getCandidateGatewayUrls();
  let lastNetworkError: unknown = null;

  for (const baseUrl of gatewayUrls) {
    try {
      const response = await fetch(`${baseUrl}/send`, {
        method: 'POST',
        headers,
        body: JSON.stringify({
          to: params.to,
          type: params.type,
          username: params.username,
          avatar_url: params.avatarUrl,
        }),
      });

      if (!response.ok) {
        const errorBody = await response.text();
        console.warn(
          `[mail-gateway] POST /send failed (${response.status}) via ${baseUrl}:`,
          errorBody,
        );
        return false;
      }

      console.log(`[mail-gateway] ${params.type} email queued for ${params.to} via ${baseUrl}`);
      return true;
    } catch (error) {
      lastNetworkError = error;
    }
  }

  const unavailableMessage =
    `[mail-gateway] Could not reach mail gateway. Tried: ${gatewayUrls.join(', ')}`;

  if (__DEV__) {
    if (!hasLoggedGatewayUnavailableInDev) {
      console.info(unavailableMessage, lastNetworkError);
      hasLoggedGatewayUnavailableInDev = true;
    }
  } else {
    console.warn(unavailableMessage, lastNetworkError);
  }

  return false;
}

/**
 * Send a welcome email after successful signup.
 * Fire-and-forget — never blocks the signup flow.
 */
export function sendWelcomeEmail(email: string, username?: string): void {
  // Don't await — this runs in the background
  sendEmail({
    to: email,
    type: 'welcome',
    username: username || email,
  }).then((success) => {
    if (!success) {
      console.warn(
        `[mail-gateway] Welcome email could not be sent to ${email}. ` +
        `Check that EXPO_PUBLIC_MAIL_GATEWAY_URL is set to the correct LAN IP ` +
        `and the mail-gateway server is running.`,
      );
    }
  }).catch(() => {
    // Silently ignore — welcome email failure is non-critical
  });
}
