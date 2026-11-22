// Tells the developer about a new Crew report, so it gets looked at within
// 24 hours (App Review Guideline 1.2). Reports are stored in crew_reports
// either way; this only sends a heads-up.
//
// Set the REPORT_WEBHOOK_URL secret to a Discord or Slack incoming-webhook
// address (both read the JSON below). Without it, nothing is sent and the
// reports wait in D1 (docs/crew-reports.md has the query to read them).

import type { Env } from "./env";

/** What was reported: a Show on the Crew feed, or a profile photo. */
export type ReportKind = "show" | "photo";

/** Posts a short note to REPORT_WEBHOOK_URL. Never throws. */
export async function notifyReport(
  env: Env,
  kind: ReportKind,
  reason: unknown,
  fetcher: typeof fetch = fetch,
): Promise<boolean> {
  const url = env.REPORT_WEBHOOK_URL?.trim();
  if (!url) return false;
  const why = typeof reason === "string" ? reason.trim().slice(0, 300) : "";
  const what = kind === "photo" ? "a profile photo" : "a Show";
  const text =
    `Setlist Tracker: someone reported ${what} on The Crew. ` +
    `Reason: "${why}". Review it within 24 hours (docs/crew-reports.md).`;
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
