# Crew reports: how to handle them

App Review Guideline 1.2 asks apps with user content to act on reports of
objectionable content within 24 hours. Here's the routine.

## Get an alert for every report

### By email (Cloudflare Email Routing)

**On** since Nov 22, 2026: every report emails ryanchengpictures@gmail.com
from reports@setlisttracker.com. Email Routing also forwards
support@setlisttracker.com there (rule "support to Ryan"). The steps below
are how it was set up:

1. Cloudflare dashboard → setlisttracker.com → **Email** → **Email Routing**
   → **Get started** → let it add its DNS records.
2. **Destination addresses** → add the address that should get reports and
   click the link in Cloudflare's verification email.
3. In `backend/wrangler.toml`, uncomment the `[[send_email]]` block and the
   `REPORT_EMAIL_TO` var. Merge, and the next deploy picks it up.

### By Discord or Slack

1. Make an incoming webhook: in Discord, **Server Settings → Integrations →
   Webhooks → New Webhook → Copy Webhook URL** (or a Slack incoming
   webhook).
2. Store it on the Worker:
   `cd backend && npx wrangler secret put REPORT_WEBHOOK_URL`, paste the URL.
   (Or Cloudflare dashboard → Workers & Pages → setlist-tracker → Settings →
   Variables and Secrets → Add → Secret, name `REPORT_WEBHOOK_URL`.)

Each new report (a Show or a profile photo) then posts a one-line note with
the reason. Without the secret, reports are still saved; nothing is sent.

## Read the reports

```
cd backend
npx wrangler d1 execute setlist-tracker --remote --command \
  "SELECT r.created_at, r.reason, r.post_id, r.reported_user, p.stage_name
     FROM crew_reports r LEFT JOIN crew_profiles p ON p.user_id = r.reported_user
    ORDER BY r.created_at DESC LIMIT 20"
```

`post_data` holds a copy of what was reported (the Show's JSON, or the photo
as base64 JPEG for `post_id = 'avatar'`).

## Act on one

The reporter already doesn't see a reported Show any more. If it breaks the
rules (web/terms.html):

- Remove a photo: `DELETE FROM crew_avatars WHERE user_id = '<reported_user>'`
- Remove the account and everything in it: the same statements as
  `deleteAccount` in `backend/src/account.ts`, with `?1` replaced by the
  user id. Run them in one `wrangler d1 execute --remote --command "…"`.
