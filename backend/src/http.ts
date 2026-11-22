// JSON responses, errors and CORS.

export type ErrorCode =
  | "not_signed_in"
  | "bad_request"
  | "not_found"
  | "need_stage_name"
  | "invite_invalid"
  | "own_invite"
  | "too_many_tries"
  | "cant_block"
  | "not_configured"
  | "upstream"
  | "server_error";

const STATUS: Record<ErrorCode, number> = {
  not_signed_in: 401,
  bad_request: 400,
  not_found: 404,
  need_stage_name: 409,
  invite_invalid: 404,
  own_invite: 409,
  too_many_tries: 429,
  cant_block: 400,
  not_configured: 503,
  upstream: 502,
  server_error: 500,
};

/** Thrown by handlers; turned into `{error, message}` by the router. */
export class ApiError extends Error {
  readonly status: number;
  constructor(
    readonly code: ErrorCode,
    message: string,
    status?: number,
    readonly extra?: Record<string, unknown>,
  ) {
    super(message);
    this.status = status ?? STATUS[code];
  }
}

export function json(body: unknown, status = 200, headers?: HeadersInit) {
  const h = new Headers(headers);
  h.set("Content-Type", "application/json; charset=utf-8");
  h.set("Cache-Control", "no-store");
  return new Response(JSON.stringify(body), { status, headers: h });
}

export function noContent(): Response {
  return new Response(null, { status: 204 });
}

export function errorResponse(e: ApiError): Response {
  return json({ error: e.code, message: e.message, ...e.extra }, e.status);
}

/** Reads a JSON object body, or throws bad_request. */
export async function readJson(
  request: Request,
): Promise<Record<string, unknown>> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    throw new ApiError("bad_request", "That request didn't make sense.");
  }
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    throw new ApiError("bad_request", "That request didn't make sense.");
  }
  return body as Record<string, unknown>;
}

const LOCAL_ORIGIN = /^http:\/\/(localhost|127\.0\.0\.1)(:\d{1,5})?$/;

/** CORS only for local Flutter dev against `wrangler dev`. */
export function corsHeaders(request: Request): Record<string, string> {
  const origin = request.headers.get("Origin");
  if (!origin || !LOCAL_ORIGIN.test(origin)) return {};
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Authorization, Content-Type",
    "Access-Control-Max-Age": "86400",
    Vary: "Origin",
  };
}

export function withCors(request: Request, response: Response): Response {
  const extra = corsHeaders(request);
  if (Object.keys(extra).length === 0) return response;
  // Redirects and some fetched responses have immutable headers.
  const r = new Response(response.body, response);
  for (const [k, v] of Object.entries(extra)) r.headers.set(k, v);
  return r;
}
