-- Crew v2: your Crew sees all your activity.
--
-- The feed no longer reads hand-shared copies (crew_posts). It reads the
-- Shows, Gear and Tours the app already syncs into `records`, leaving out
-- deleted Shows and Shows marked "Keep off the Crew" (`crewPrivate`).
-- A post is now named "<ownerId>:<showId>".
--
-- crew_profiles keeps always_share, show_opening_night, opening_night and
-- tour_name (dropping columns on D1 is awkward), but nothing uses them.

-- Encores now point at a synced Show: (owner, show_id).
CREATE TABLE crew_encores_v2 (
  owner TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  show_id TEXT NOT NULL,
  user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at TEXT NOT NULL,
  PRIMARY KEY (owner, show_id, user_id)
);
CREATE INDEX crew_encores_v2_user_idx ON crew_encores_v2 (user_id);

INSERT OR IGNORE INTO crew_encores_v2 (owner, show_id, user_id, created_at)
SELECT p.owner, p.show_id, e.user_id, e.created_at
FROM crew_encores e
JOIN crew_posts p ON p.id = e.post_id;

-- Reports: post_id now holds the Show's id (reported_user is its owner).
-- Reports on posts that were already unshared keep their old uuid.
UPDATE crew_reports
SET post_id = (SELECT p.show_id FROM crew_posts p WHERE p.id = crew_reports.post_id)
WHERE post_id IN (SELECT id FROM crew_posts);

DROP TABLE crew_encores;
DROP TABLE crew_posts;
