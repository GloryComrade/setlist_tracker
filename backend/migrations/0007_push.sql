-- Push notifications: "Maya played a Show".
--
-- push_devices holds each signed-in iPhone's APNs device token. The app
-- registers it after the runner allows notifications, and removes it on
-- sign-out. A token belongs to one runner at a time: registering it again
-- under another account moves it. APNs answers 410 (or BadDeviceToken) for
-- a token that no longer works, and that row is deleted.
--
-- crew_profiles.notify_shows is the Settings switch "Tell me when my Crew
-- plays a Show". Off, none of your phones get those notifications.

CREATE TABLE push_devices (
  token TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  sandbox INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL
);
CREATE INDEX push_devices_user_idx ON push_devices (user_id);

ALTER TABLE crew_profiles ADD COLUMN notify_shows INTEGER NOT NULL DEFAULT 1;
