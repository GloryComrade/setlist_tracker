// GET /api/me and DELETE /api/me (Delete account).

import type { Env } from "./env";
import { revokeAppleTokens } from "./oauth";

/**
 * Deletes [userId] and every row of theirs. Foreign keys would cascade from
 * users, but each table is cleared explicitly, in one batch (one
 * transaction), so nothing is left behind if a cascade is ever missing.
 */
export async function deleteAccount(env: Env, userId: string): Promise<void> {
  // Revoke Sign in with Apple first (best effort), while the tokens exist.
  try {
    await revokeAppleTokens(env, userId);
  } catch (e) {
    console.error("Apple revoke failed", e);
  }
  const db = env.DB;
  const one = (sql: string) => db.prepare(sql).bind(userId);
  await db.batch([
    one("DELETE FROM crew_tour_invites WHERE from_user = ?1 OR to_user = ?1"),
    one("DELETE FROM crew_encores_v2 WHERE user_id = ?1 OR owner = ?1"),
    one("DELETE FROM crew_reports WHERE reporter = ?1 OR reported_user = ?1"),
    one("DELETE FROM crew_invites WHERE owner = ?1"),
    one("DELETE FROM crew_invite_misses WHERE user_id = ?1"),
    one("DELETE FROM crew_blocks WHERE blocker = ?1 OR blocked = ?1"),
    one("DELETE FROM crew_links WHERE user_a = ?1 OR user_b = ?1"),
    one("DELETE FROM crew_profiles WHERE user_id = ?1"),
    one("DELETE FROM records WHERE user_id = ?1"),
    one("DELETE FROM sessions WHERE user_id = ?1"),
    one("DELETE FROM login_codes WHERE user_id = ?1"),
    one("DELETE FROM apple_tokens WHERE user_id = ?1"),
    one("DELETE FROM users WHERE id = ?1"),
  ]);
}
