import { applyD1Migrations } from "cloudflare:test";
import { env } from "cloudflare:workers";

// Setup files run before each test file; applyD1Migrations skips what's
// already applied.
await applyD1Migrations(env.DB, env.TEST_MIGRATIONS);
