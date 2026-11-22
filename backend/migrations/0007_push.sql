-- Push notifications on iPhone (src/push.ts, docs/push-setup.md).
--
-- push_devices: one row per APNs device token. A token belongs to one
-- runner at a time: signing in with another account on the same phone moves
-- it. The app deletes its token on sign-out and when both switches are off;
-- APNs answering 410 (or 400 BadDeviceToken / Unregistered) deletes it too.
--
-- crew_profiles.push_shows / push_shoutouts are the Settings switches
-- "When my Crew logs a Show" and "Shout-outs on my Shows".
--
-- push_sent: when a Show push went from one runner to a mate, so a mate gets
-- at most one Show push per runner per hour. Rows older than a day are
-- pruned as new ones are written.

CREATE TABLE push_devices (
  token TEXT PRIMARY KEY,                    -- hex, lowercase
  user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  platform TEXT NOT NULL DEFAULT 'ios',
  environment TEXT NOT NULL CHECK (environment IN ('sandbox', 'production')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE INDEX push_devices_user_idx ON push_devices (user_id);

ALTER TABLE crew_profiles ADD COLUMN push_shows INTEGER NOT NULL DEFAULT 1;
ALTER TABLE crew_profiles ADD COLUMN push_shoutouts INTEGER NOT NULL DEFAULT 1;

CREATE TABLE push_sent (
  from_user TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  to_user TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  kind TEXT NOT NULL,                        -- 'show'
  sent_at TEXT NOT NULL
);
CREATE INDEX push_sent_pair_idx ON push_sent (from_user, to_user, kind, sent_at);
CREATE INDEX push_sent_to_idx ON push_sent (to_user);
