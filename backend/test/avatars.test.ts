import { env } from "cloudflare:workers";
import { describe, expect, it } from "vitest";
import { AVATAR_BADGES, MAX_AVATAR_BYTES } from "../src/avatars";
import worker from "../src/index";
import { call, callJson, count, newRunner, ORIGIN, type Runner } from "./helpers";

async function profile(r: Runner, stageName: string, extra: Record<string, unknown> = {}) {
  const res = await callJson("PUT", "/api/crew/profile", {
    token: r.token,
    body: { stageName, color: 1, ...extra },
  });
  expect(res.status).toBe(200);
  return res.body;
}

async function crewPair() {
  const maya = await newRunner("Maya");
  const ryan = await newRunner("Ryan");
  await profile(maya, "Maya");
  await profile(ryan, "Ryan");
  const code = (await callJson("POST", "/api/crew/invite", { token: maya.token })).body.code;
  expect((await call("POST", "/api/crew/join", { token: ryan.token, body: { code } })).status).toBe(200);
  return { maya, ryan };
}

/** A tiny fake JPEG: the magic bytes, then [size] bytes in all. */
function jpeg(size = 200, fill = 7): Uint8Array {
  const b = new Uint8Array(size).fill(fill);
  b.set([0xff, 0xd8, 0xff, 0xe0]);
  return b;
}

async function putPhoto(
  r: Runner,
  bytes: Uint8Array,
  type = "image/jpeg",
): Promise<{ status: number; body: any }> {
  const res = await worker.fetch(
    new Request(`${ORIGIN}/api/crew/avatar`, {
      method: "PUT",
      headers: { Authorization: `Bearer ${r.token}`, "Content-Type": type },
      body: bytes,
    }),
    env,
  );
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null };
}

async function getPhoto(r: Runner, url: string) {
  return call("GET", url, { token: r.token });
}

describe("badges", () => {
  it("are saved with the profile, cleared with null, and kept when left out", async () => {
    const r = await newRunner();
    const first = await profile(r, "Ryan");
    expect(first.avatarBadge).toBeNull();
    expect(first.avatarUrl).toBeNull();

    expect((await profile(r, "Ryan", { avatarBadge: "vinyl" })).avatarBadge).toBe("vinyl");
    // Older app builds send no avatarBadge: the badge stays.
    expect((await profile(r, "Ryan 2")).avatarBadge).toBe("vinyl");
    const got = await callJson("GET", "/api/crew/profile", { token: r.token });
    expect(got.body.avatarBadge).toBe("vinyl");
    expect((await profile(r, "Ryan", { avatarBadge: null })).avatarBadge).toBeNull();
  });

  it("only from the list", async () => {
    const r = await newRunner();
    for (const bad of ["unicorn", 3, "", "VINYL"]) {
      const res = await callJson("PUT", "/api/crew/profile", {
        token: r.token,
        body: { stageName: "Ryan", avatarBadge: bad },
      });
      expect(res.status, String(bad)).toBe(400);
    }
    expect(AVATAR_BADGES).toHaveLength(24);
    expect(new Set(AVATAR_BADGES).size).toBe(24);
  });

  it("show on mates and the feed", async () => {
    const { maya, ryan } = await crewPair();
    await profile(maya, "Maya", { avatarBadge: "crown" });
    const mates = (await callJson("GET", "/api/crew/mates", { token: ryan.token })).body.mates;
    expect(mates[0].avatarBadge).toBe("crown");
    expect(mates[0].avatarUrl).toBeNull();
    const id = crypto.randomUUID();
    await call("POST", "/api/sync/shows", {
      token: maya.token,
      body: { rows: [{ id, data: { id, date: "2026-11-21T07:30:00.000" }, updatedAt: new Date().toISOString(), deletedAt: null }] },
    });
    const posts = (await callJson("GET", "/api/crew/feed", { token: ryan.token })).body.posts;
    expect(posts[0].avatarBadge).toBe("crown");
    const detail = (await callJson("GET", `/api/crew/mates/${maya.user.id}`, { token: ryan.token })).body;
    expect(detail.mate.avatarBadge).toBe("crown");
  });
});

describe("photos", () => {
  it("upload, fetch with a version, replace, delete", async () => {
    const { maya, ryan } = await crewPair();
    const put = await putPhoto(maya, jpeg(300, 1));
    expect(put.status).toBe(200);
    const url: string = put.body.avatarUrl;
    expect(url).toMatch(new RegExp(`^/api/crew/avatar/${maya.user.id}\\?v=\\d+$`));

    // Yourself and your Crew.
    for (const who of [maya, ryan]) {
      const res = await getPhoto(who, url);
      expect(res.status).toBe(200);
      expect(res.headers.get("Content-Type")).toBe("image/jpeg");
      expect(res.headers.get("Cache-Control")).toContain("private");
      const bytes = new Uint8Array(await res.arrayBuffer());
      expect(bytes.length).toBe(300);
      expect(bytes[10]).toBe(1);
    }

    // Mates, the feed and the profile all carry the same address.
    const mates = (await callJson("GET", "/api/crew/mates", { token: ryan.token })).body.mates;
    expect(mates[0].avatarUrl).toBe(url);
    expect((await callJson("GET", "/api/crew/profile", { token: maya.token })).body.avatarUrl).toBe(url);

    // A new photo gets a new address.
    await new Promise((r) => setTimeout(r, 5));
    const again = await putPhoto(maya, jpeg(310, 2));
    expect(again.body.avatarUrl).not.toBe(url);
    expect(new Uint8Array(await (await getPhoto(ryan, again.body.avatarUrl)).arrayBuffer())[10]).toBe(2);

    const del = await callJson("DELETE", "/api/crew/avatar", { token: maya.token });
    expect(del.status).toBe(200);
    expect(del.body.avatarUrl).toBeNull();
    expect((await getPhoto(maya, url)).status).toBe(404);
  });

  it("strangers and blocked runners never get it", async () => {
    const { maya, ryan } = await crewPair();
    const stranger = await newRunner("Stranger");
    await profile(stranger, "Stranger");
    const url = (await putPhoto(maya, jpeg())).body.avatarUrl;
    expect((await getPhoto(stranger, url)).status).toBe(404);
    expect((await call("GET", url)).status).toBe(401);

    // Maya blocks Ryan: Ryan can't fetch it, and Maya's list shows Ryan
    // without a picture.
    await putPhoto(ryan, jpeg());
    await call("POST", "/api/crew/blocks", { token: maya.token, body: { userId: ryan.user.id } });
    expect((await getPhoto(ryan, url)).status).toBe(404);
    const mates = (await callJson("GET", "/api/crew/mates", { token: maya.token })).body.mates;
    expect(mates[0].blocked).toBe(true);
    expect(mates[0].avatarUrl).toBeNull();
    expect(mates[0].avatarBadge).toBeNull();
  });

  it("must be a JPEG of 64 KB or less, from a runner with a stage name", async () => {
    const r = await newRunner();
    expect((await putPhoto(r, jpeg())).status).toBe(409);
    await profile(r, "Ryan");
    expect((await putPhoto(r, jpeg(), "image/png")).status).toBe(415);
    const png = new Uint8Array(100).fill(0);
    png.set([0x89, 0x50, 0x4e, 0x47]);
    expect((await putPhoto(r, png)).status).toBe(400);
    expect((await putPhoto(r, jpeg(MAX_AVATAR_BYTES + 1))).status).toBe(413);
    expect((await putPhoto(r, jpeg(MAX_AVATAR_BYTES))).status).toBe(200);
  });

  it("can be reported by a Crew mate, with a copy of the photo", async () => {
    const { maya, ryan } = await crewPair();
    await putPhoto(maya, jpeg(120, 9));
    const bad = await call("POST", "/api/crew/report-avatar", {
      token: ryan.token,
      body: { userId: maya.user.id, reason: "" },
    });
    expect(bad.status).toBe(400);
    const own = await call("POST", "/api/crew/report-avatar", {
      token: maya.token,
      body: { userId: maya.user.id, reason: "x" },
    });
    expect(own.status).toBe(400);
    const res = await call("POST", "/api/crew/report-avatar", {
      token: ryan.token,
      body: { userId: maya.user.id, reason: "Not a runner" },
    });
    expect(res.status).toBe(204);
    const row = await env.DB.prepare(
      "SELECT post_id, post_data, reason FROM crew_reports WHERE reporter = ? AND reported_user = ?",
    ).bind(ryan.user.id, maya.user.id).first<{ post_id: string; post_data: string; reason: string }>();
    expect(row?.post_id).toBe("avatar");
    expect(row?.reason).toBe("Not a runner");
    const data = JSON.parse(row!.post_data);
    expect(data.kind).toBe("avatar");
    expect(atob(data.jpegBase64).length).toBe(120);

    // Outside the Crew (or with no photo) there's nothing to report.
    const stranger = await newRunner("Stranger");
    await profile(stranger, "Stranger");
    const strangerReport = await call("POST", "/api/crew/report-avatar", {
      token: stranger.token,
      body: { userId: maya.user.id, reason: "x" },
    });
    expect(strangerReport.status).toBe(404);
    const noPhoto = await call("POST", "/api/crew/report-avatar", {
      token: maya.token,
      body: { userId: ryan.user.id, reason: "x" },
    });
    expect(noPhoto.status).toBe(404);
  });

  it("goes with the account", async () => {
    const r = await newRunner();
    await profile(r, "Ryan");
    await putPhoto(r, jpeg());
    expect(await count("SELECT count(*) AS n FROM crew_avatars WHERE user_id = ?", r.user.id)).toBe(1);
    expect((await call("DELETE", "/api/me", { token: r.token })).status).toBe(204);
    expect(await count("SELECT count(*) AS n FROM crew_avatars WHERE user_id = ?", r.user.id)).toBe(0);
  });
});
