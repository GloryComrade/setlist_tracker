import { env } from "cloudflare:workers";
import { describe, expect, it, vi } from "vitest";
import type { Env } from "../src/env";
import { notifyReport, reportText } from "../src/reports";

const base = env as unknown as Env;

describe("notifyReport", () => {
  it("sends nothing without REPORT_WEBHOOK_URL", async () => {
    const f = vi.fn();
    expect(await notifyReport({ ...base, REPORT_WEBHOOK_URL: undefined }, "show", "spam", f)).toBe(false);
    expect(f).not.toHaveBeenCalled();
  });

  it("posts a Slack/Discord-shaped note with the reason", async () => {
    const f = vi.fn(async () => new Response(null, { status: 204 }));
    const ok = await notifyReport(
      { ...base, REPORT_WEBHOOK_URL: "https://hooks.example.com/x" },
      "photo",
      "  not a runner  ",
      f as unknown as typeof fetch,
    );
    expect(ok).toBe(true);
    const [url, init] = f.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe("https://hooks.example.com/x");
    const body = JSON.parse(init.body as string);
    expect(body.text).toContain("a profile photo");
    expect(body.text).toContain('"not a runner"');
    expect(body.content).toBe(body.text);
  });

  it("emails the note when REPORT_EMAIL is bound", async () => {
    const send = vi.fn(async () => ({}));
    const ok = await notifyReport(
      { ...base, REPORT_WEBHOOK_URL: undefined, REPORT_EMAIL: { send } as unknown as SendEmail, REPORT_EMAIL_TO: "me@example.com" },
      "show",
      "spam",
    );
    expect(ok).toBe(true);
    const msg = (send.mock.calls[0] as unknown as [any])[0];
    expect(msg.to).toBe("me@example.com");
    expect(msg.subject).toBe("New Crew report");
    expect(msg.text).toContain('"spam"');
  });

  it("never throws when the webhook is down", async () => {
    const f = vi.fn(async () => {
      throw new Error("offline");
    });
    const ok = await notifyReport(
      { ...base, REPORT_WEBHOOK_URL: "https://hooks.example.com/x" },
      "show",
      "x",
      f as unknown as typeof fetch,
    );
    expect(ok).toBe(false);
  });
});

describe("reportText", () => {
  it("names a Shout-out", () => {
    expect(reportText("shoutout", "mean")).toContain("a Shout-out");
  });
});
