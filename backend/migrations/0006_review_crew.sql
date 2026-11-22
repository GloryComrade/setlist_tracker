-- "Review Crew": a demo runner for App Review (and anyone Ryan wants to show
-- The Crew to). Its invite code TRYCREW2 never expires, so the App Store
-- review notes can name it without a fresh code before every submission.
--
-- Nobody can sign in as this runner: its Apple subject id is not a real one.
-- Joining with the code links you to Review Crew only, never to the other
-- people who joined. To retire it, delete the crew_invites row (the runner
-- and its Shows can stay), or delete the users row to remove everything.

INSERT OR IGNORE INTO users (id, provider, provider_sub, name, email, created_at)
VALUES ('review-crew', 'apple', 'setlist-tracker-review-crew', 'Review Crew', NULL,
        '2026-11-22T21:40:00.000Z');

INSERT OR IGNORE INTO crew_profiles (user_id, stage_name, color, updated_at)
VALUES ('review-crew', 'Review Crew', 3, '2026-11-22T21:40:00.000Z');

INSERT OR IGNORE INTO crew_invites (code, owner, created_at, expires_at)
VALUES ('TRYCREW2', 'review-crew', '2026-11-22T21:40:00.000Z',
        '9999-12-31T00:00:00.000Z');

INSERT OR IGNORE INTO records (user_id, kind, id, data, updated_at, deleted_at, synced_at)
VALUES
('review-crew', 'shows', 'review-crew-show-1',
 '{"schemaVersion":1,"id":"review-crew-show-1","date":"2026-11-21T07:15:00.000","venue":"live","workoutType":"long","distanceMiles":10.2,"durationSeconds":5814,"effort":7,"feel":"encore","notes":"Ten along the river. Negative split the last three, legs felt great.","gearId":null,"song":null,"studio":null,"live":null,"plannedShowId":null,"healthWorkoutId":null,"createdAt":"2026-11-21T15:20:00.000Z","updatedAt":"2026-11-21T15:20:00.000Z","deletedAt":null}',
 '2026-11-21T15:20:00.000Z', NULL, '2026-11-22T21:40:00.000Z'),
('review-crew', 'shows', 'review-crew-show-2',
 '{"schemaVersion":1,"id":"review-crew-show-2","date":"2026-11-19T18:05:00.000","venue":"studio","workoutType":"intervals","distanceMiles":5.0,"durationSeconds":2580,"effort":8,"feel":"good","notes":"6 x 800 on the treadmill. Last rep was the fastest.","gearId":null,"song":null,"studio":null,"live":null,"plannedShowId":null,"healthWorkoutId":null,"createdAt":"2026-11-20T02:10:00.000Z","updatedAt":"2026-11-20T02:10:00.000Z","deletedAt":null}',
 '2026-11-20T02:10:00.000Z', NULL, '2026-11-22T21:40:00.000Z'),
('review-crew', 'shows', 'review-crew-show-3',
 '{"schemaVersion":1,"id":"review-crew-show-3","date":"2026-11-17T06:40:00.000","venue":"live","workoutType":"easy","distanceMiles":4.1,"durationSeconds":2460,"effort":4,"feel":"fine","notes":"Easy shakeout before work.","gearId":null,"song":null,"studio":null,"live":null,"plannedShowId":null,"healthWorkoutId":null,"createdAt":"2026-11-17T14:30:00.000Z","updatedAt":"2026-11-17T14:30:00.000Z","deletedAt":null}',
 '2026-11-17T14:30:00.000Z', NULL, '2026-11-22T21:40:00.000Z');

INSERT OR IGNORE INTO crew_shoutouts (id, owner, show_id, user_id, body, created_at)
VALUES ('review-crew-shoutout-1', 'review-crew', 'review-crew-show-1', 'review-crew',
        'Ten miles in the books. Who''s joining for the next one?',
        '2026-11-21T15:25:00.000Z');
