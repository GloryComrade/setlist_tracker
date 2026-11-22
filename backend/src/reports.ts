// Tells the developer about a new Crew report, so it gets looked at within
// 24 hours (App Review Guideline 1.2). Reports are stored in crew_reports
// either way; this only sends a heads-up.
//
// Two ways to be told, either or both:
// - REPORT_EMAIL: a send_email binding (wrangler.toml) that mails the
//   developer through Cloudflare Email Routing.
// - REPORT_WEBHOOK_URL: a Discord or Slack incoming-webhook secret (both
//   read the JSON below).
// Without either, nothing is sent and the reports wait in D1
// (docs/crew-reports.md has the query to read them).

import type { Env } from "./env";

/** What was reported: a Show on the Crew feed, or a profile photo. */
export type ReportKind = "show" | "photo";

/** The one-line note about a report. */
export function reportText(kind: ReportKind, reason: unknown): string {
  const why = typeof reason === "string" ? reason.trim().slice(0, 300) : "";
  const what = kind === "photo" ? "a profile photo" : "a Show";
  return (
    `Setlist Tracker: someone reported ${what} on The Crew. ` +
    `Reason: "${why}". Review it within 24 hours (docs/crew-reports.md).`
  );
}

/** Emails and/or posts the note. Never throws. True if anything was sent. */
export async function notifyReport(
  env: Env,
  kind: ReportKind,
  reason: unknown,
  fetcher: typeof fetch = fetch,
): Promise<boolean> {
  const text = reportText(kind, reason);
  const [mailed, posted] = await Promise.all([
    emailReport(env, text),
    postReport(env, text, fetcher),
  ]);
  return mailed || posted;
}

async function emailReport(env: Env, text: string): Promise<boolean> {
  const mail = env.REPORT_EMAIL;
  const to = env.REPORT_EMAIL_TO?.trim();
  if (!mail || !to) return false;
  try {
    await mail.send({
      from: { name: "Setlist Tracker", email: env.REPORT_EMAIL_FROM ?? "reports@setlisttracker.com" },
      to,
      subject: "New Crew report",
      text,
    });
    return true;
  } catch (e) {
    console.error("Report email failed", e);
    return false;
  }
}

async function postReport(
  env: Env,
  text: string,
  fetcher: typeof fetch,
): Promise<boolean> {
  const url = env.REPORT_WEBHOOK_URL?.trim();
  if (!url) return false;
  try {
    const res = await fetcher(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      // Slack reads `text`, Discord reads `content`.
      body: JSON.stringify({ text, content: text }),
    });
    return res.ok;
  } catch (e) {
    console.error("Report webhook failed", e);
    return false;
  }
}
