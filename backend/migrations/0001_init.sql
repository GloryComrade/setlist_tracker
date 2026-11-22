-- Setlist Tracker on D1 (SQLite). Apply with:
--   npx wrangler d1 migrations apply setlist-tracker --remote
--
-- All times are ISO 8601 UTC text with milliseconds
-- (2026-11-22T03:04:05.678Z), so they sort and compare as plain strings.
-- Booleans are 0/1 integers. JSON is stored as text.
--
-- Foreign keys cascade from users, but DELETE /api/me also deletes every
-- table explicitly, so nothing depends on the cascade alone.

-- ---- Accounts and sign-in ----

CREATE TABLE users (
  id TEXT PRIMARY KEY,                       -- uuid
  provider TEXT NOT NULL CHECK (provider IN ('google', 'apple')),
  provider_sub TEXT NOT NULL,                -- the provider's subject id
  name TEXT,
  email TEXT,
  created_at TEXT NOT NULL,
  UNIQUE (provider, provider_sub)
);

-- Apple refresh tokens, kept only so Delete account can revoke them.
-- client_id is the bundle ID (native) or the Services ID (web).
CREATE TABLE apple_tokens (
  user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  client_id TEXT NOT NULL,
  refresh_token TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (user_id, client_id)
);

-- Refresh tokens. Only the SHA-256 (base64url) of each token is stored.
CREATE TABLE sessions (
  token_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL
);
CREATE INDEX sessions_user_idx ON sessions (user_id);
CREATE INDEX sessions_expires_idx ON sessions (expires_at);

-- A browser sign-in in progress (10 minutes).
CREATE TABLE oauth_states (
  state TEXT PRIMARY KEY,
  provider TEXT NOT NULL,
  verifier TEXT NOT NULL,                    -- PKCE code verifier
  nonce TEXT NOT NULL,
  return_url TEXT NOT NULL,
  expires_at TEXT NOT NULL
);
CREATE INDEX oauth_states_expires_idx ON oauth_states (expires_at);

-- One-time login codes handed back to the app (60 seconds, single use).
-- Only the SHA-256 of each code is stored.
CREATE TABLE login_codes (
  code_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  expires_at TEXT NOT NULL
);
CREATE INDEX login_codes_user_idx ON login_codes (user_id);
CREATE INDEX login_codes_expires_idx ON login_codes (expires_at);

-- ---- Backstage Pass (sync) ----

-- One table for every synced kind. The primary key is (kind, id), so a
-- record id belongs to exactly one runner.
CREATE TABLE records (
  user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('shows', 'gear', 'saved_mixes', 'tours')),
  id TEXT NOT NULL,
  data TEXT NOT NULL,                        -- the record's JSON
  updated_at TEXT NOT NULL,                  -- the app's clock
  deleted_at TEXT,                           -- soft delete (the app's clock)
  synced_at TEXT NOT NULL,                   -- the server's clock
  PRIMARY KEY (kind, id)
);
CREATE INDEX records_pull_idx ON records (user_id, kind, synced_at, id);

-- ---- The Crew ----

CREATE TABLE crew_profiles (
  user_id TEXT PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
  stage_name TEXT NOT NULL CHECK (length(stage_name) BETWEEN 1 AND 30),
  color INTEGER NOT NULL DEFAULT 0 CHECK (color BETWEEN 0 AND 7),
  always_share INTEGER NOT NULL DEFAULT 0,
  -- Opening Night and the Tour's name are kept only while this is on.
  show_opening_night INTEGER NOT NULL DEFAULT 0,
  opening_night TEXT,                        -- YYYY-MM-DD
  tour_name TEXT CHECK (tour_name IS NULL OR length(tour_name) <= 60),
  updated_at TEXT NOT NULL
);

-- One row per pair of runners in each other's Crew, smaller id first.
CREATE TABLE crew_links (
  user_a TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  user_b TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at TEXT NOT NULL,
  PRIMARY KEY (user_a, user_b),
  CHECK (user_a < user_b)
);
CREATE INDEX crew_links_b_idx ON crew_links (user_b);

-- Each runner's block is their own row, so one can't undo the other's.
CREATE TABLE crew_blocks (
  blocker TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  blocked TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at TEXT NOT NULL,
  PRIMARY KEY (blocker, blocked),
  CHECK (blocker <> blocked)
);
CREATE INDEX crew_blocks_blocked_idx ON crew_blocks (blocked);

CREATE TABLE crew_invites (
  code TEXT PRIMARY KEY,
  owner TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL
);
CREATE INDEX crew_invites_owner_idx ON crew_invites (owner);

-- Wrong invite codes tried, so nobody can guess their way into a Crew.
CREATE TABLE crew_invite_misses (
  user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  at TEXT NOT NULL
);
CREATE INDEX crew_invite_misses_idx ON crew_invite_misses (user_id, at);
CREATE INDEX crew_invite_misses_at_idx ON crew_invite_misses (at);

-- A snapshot of a Show its owner shared. One post per Show.
CREATE TABLE crew_posts (
  id TEXT PRIMARY KEY,                       -- uuid
  owner TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  show_id TEXT NOT NULL,
  data TEXT NOT NULL,                        -- SharedShow JSON
  show_updated_at TEXT NOT NULL,
  created_at TEXT NOT NULL,                  -- sharedAt, the server's clock
  updated_at TEXT NOT NULL,
  UNIQUE (owner, show_id)
);
CREATE INDEX crew_posts_created_idx ON crew_posts (created_at);

CREATE TABLE crew_encores (
  post_id TEXT NOT NULL REFERENCES crew_posts (id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at TEXT NOT NULL,
  PRIMARY KEY (post_id, user_id)
);
CREATE INDEX crew_encores_user_idx ON crew_encores (user_id);

-- Reports for the app's owner to read (wrangler d1 execute ... "select ...").
-- post_id has no foreign key, so a report outlives an unshared post.
CREATE TABLE crew_reports (
  id TEXT PRIMARY KEY,                       -- uuid
  reporter TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  post_id TEXT NOT NULL,
  reported_user TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  post_data TEXT NOT NULL,                   -- copied from the post by the server
  reason TEXT NOT NULL CHECK (length(reason) BETWEEN 1 AND 500),
  created_at TEXT NOT NULL
);
CREATE INDEX crew_reports_reporter_idx ON crew_reports (reporter, post_id);
CREATE INDEX crew_reports_reported_idx ON crew_reports (reported_user);
