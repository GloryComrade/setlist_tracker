/** Bindings, vars (wrangler.toml) and secrets (`wrangler secret put`). */
export interface Env {
  DB: D1Database;
  ASSETS: Fetcher;

  APPLE_BUNDLE_ID: string;
  APPLE_SERVICES_ID: string;
  NATIVE_REDIRECT: string;

  SESSION_SECRET?: string;
  GOOGLE_CLIENT_ID?: string;
  GOOGLE_CLIENT_SECRET?: string;
  APPLE_TEAM_ID?: string;
  APPLE_KEY_ID?: string;
  APPLE_PRIVATE_KEY?: string;
  SPOTIFY_CLIENT_ID?: string;
  SPOTIFY_CLIENT_SECRET?: string;
  /** Discord or Slack webhook told about each new Crew report (optional). */
  REPORT_WEBHOOK_URL?: string;
  /** Mails each new Crew report (send_email binding, optional). */
  REPORT_EMAIL?: SendEmail;
  /** Where report emails go; must be a verified Email Routing address. */
  REPORT_EMAIL_TO?: string;
  /** Sender on the Email Routing domain. */
  REPORT_EMAIL_FROM?: string;
  /** APNs auth key (.p8 contents, PKCS#8 PEM) for push notifications (optional). */
  APNS_KEY?: string;
  /** The APNs key's Key ID. */
  APNS_KEY_ID?: string;
  /** The Apple Developer Team ID that owns the key. */
  APNS_TEAM_ID?: string;
}
