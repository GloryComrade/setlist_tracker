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
}
