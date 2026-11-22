-- "Seen by": which Crew mates have seen a Show.
--
-- A view is recorded when a Crew mate opens a Show or its feed card stays
-- on screen for about a second (PUT /api/crew/posts/{postId}/seen). Only the
-- Show's owner can list who saw it. The first view is kept; seeing it again
-- changes nothing.
--
-- crew_profiles.share_views is the Settings switch "Let my Crew know when
-- I've seen their Shows". Turned off, your views stop being recorded and
-- the ones already kept are deleted.

ALTER TABLE crew_profiles ADD COLUMN share_views INTEGER NOT NULL DEFAULT 1;

CREATE TABLE crew_show_views (
  owner TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  show_id TEXT NOT NULL,
  user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  seen_at TEXT NOT NULL,
  PRIMARY KEY (owner, show_id, user_id),
  CHECK (owner <> user_id)
);
CREATE INDEX crew_show_views_user_idx ON crew_show_views (user_id);

-- Shout-outs: short comments on a Show (1 to 280 characters) from the Show's
-- owner and their Crew. The writer can delete one, and so can the Show's
-- owner. Reports go in crew_reports with post_id 'shoutout:<id>' and a copy
-- of the text. Writers who left the owner's Crew, or are blocked either way
-- with the reader, are hidden rather than deleted.
CREATE TABLE crew_shoutouts (
  id TEXT PRIMARY KEY,                       -- uuid
  owner TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  show_id TEXT NOT NULL,
  user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  body TEXT NOT NULL CHECK (length(body) BETWEEN 1 AND 1000),
  created_at TEXT NOT NULL
);
CREATE INDEX crew_shoutouts_show_idx ON crew_shoutouts (owner, show_id, created_at);
CREATE INDEX crew_shoutouts_user_idx ON crew_shoutouts (user_id, created_at);
