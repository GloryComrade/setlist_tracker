-- Tour invites: "Ryan invited you on the Spring 2027 Half Tour".
--
-- A runner invites Crew mates onto one of their synced Tours. The race
-- (date, distance, name) is copied from the Tour when the invite is sent;
-- GET /api/crew/tour-invites prefers the Tour's current values while it
-- still exists. The recipient can dismiss an invite ("Not this time"); a
-- dismissed invite stays dismissed if the same Tour is offered again.

CREATE TABLE crew_tour_invites (
  id TEXT PRIMARY KEY,                       -- uuid
  from_user TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  to_user TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  tour_id TEXT NOT NULL,                     -- records (kind 'tours') id
  race_date TEXT NOT NULL,                   -- YYYY-MM-DD
  race_distance TEXT NOT NULL,
  tour_name TEXT NOT NULL,
  created_at TEXT NOT NULL,
  dismissed_at TEXT,
  UNIQUE (from_user, to_user, tour_id),
  CHECK (from_user <> to_user)
);
CREATE INDEX crew_tour_invites_to_idx ON crew_tour_invites (to_user, race_date);
