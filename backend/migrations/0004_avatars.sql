-- Profile pictures for The Crew.
--
-- A runner's picture is their photo if they uploaded one, else a drawn
-- tour-art badge (avatar_badge, one of AVATAR_BADGES in src/avatars.ts),
-- else their initial. Photos are 256 px square JPEGs made on the device,
-- at most 64 KB, kept here in D1 so there is no extra storage to run.
-- Only the runner and their Crew can fetch a photo; a block hides it.
-- Reports on a photo go in crew_reports with post_id 'avatar'.

ALTER TABLE crew_profiles ADD COLUMN avatar_badge TEXT;

CREATE TABLE crew_avatars (
  user_id TEXT PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
  jpeg BLOB NOT NULL CHECK (length(jpeg) <= 65536),
  updated_at TEXT NOT NULL
);
