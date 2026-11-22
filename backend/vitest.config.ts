import { generateKeyPairSync } from "node:crypto";
import path from "node:path";
import { cloudflareTest, readD1Migrations } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

// Tests run in the Workers runtime (Miniflare) with a local D1 database. The
// migrations are read here, in Node, and applied in test/setup.ts.
const migrations = await readD1Migrations(path.join(import.meta.dirname, "migrations"));

// A throwaway Apple .p8-style key, so the ES256 client secret can be signed.
const applePrivateKey = generateKeyPairSync("ec", { namedCurve: "P-256" })
  .privateKey.export({ type: "pkcs8", format: "pem" })
  .toString();

export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: "./wrangler.toml" },
      miniflare: {
        bindings: {
          TEST_MIGRATIONS: migrations,
          SESSION_SECRET: "test-session-secret-that-is-long-enough",
          GOOGLE_CLIENT_ID: "test-google-client.apps.googleusercontent.com",
          GOOGLE_CLIENT_SECRET: "test-google-secret",
          APPLE_TEAM_ID: "TEAM123456",
          APPLE_KEY_ID: "KEY1234567",
          APPLE_PRIVATE_KEY: applePrivateKey,
          // No Spotify secrets: tests add them where needed.
        },
      },
    }),
  ],
  test: {
    setupFiles: ["./test/setup.ts"],
  },
});
