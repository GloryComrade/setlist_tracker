/// Talks to the Cloudflare Worker (backend/, contract in
/// docs/cloudflare-api.md): finds its address, keeps the Backstage Pass
/// session on the device, and refreshes the access token before it runs
/// out or when the Worker says it has.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:sembast/sembast.dart';

/// Where the API lives, from the `API_URL` build setting.
///
/// - Empty: no backend, the app stays local-only (returns null).
/// - `same-origin`: on the web, the address the page was loaded from
///   ([page]); anywhere else there is no page, so no backend.
/// - Anything else: the Worker's full address, e.g.
///   `https://setlist-tracker.example.workers.dev`.
///
/// The answer never ends in a slash, so paths like `/api/me` go straight on.
String? resolveApiBaseUrl(
  String setting, {
  required bool isWeb,
  required Uri page,
}) {
  final v = setting.trim();
  if (v.isEmpty) return null;
  if (v == 'same-origin') {
    if (!isWeb || (page.scheme != 'http' && page.scheme != 'https')) {
      return null;
    }
    return page.origin;
  }
  return v.endsWith('/') ? v.substring(0, v.length - 1) : v;
}

/// ISO 8601 in UTC with milliseconds (`2026-11-22T03:04:05.678Z`), the
/// Worker's time format.
String apiTime(DateTime d) {
  final u = d.toUtc();
  return DateTime.utc(
    u.year,
    u.month,
    u.day,
    u.hour,
    u.minute,
    u.second,
    u.millisecond,
  ).toIso8601String();
}

/// Something the Worker refused: its HTTP status plus the `{error, message}`
/// it sent back.
class ApiException implements Exception {
  const ApiException(this.status, this.code, [this.message = '']);

  final int status;

  /// e.g. `not_signed_in`, `invite_invalid`, `not_configured`.
  final String code;

  /// Words for a runner, when the Worker gave any.
  final String message;

  @override
  String toString() =>
      'ApiException($status $code${message.isEmpty ? '' : ': $message'})';
}

/// The signed-in runner, as the Worker describes them.
class ApiUser {
  const ApiUser({required this.id, this.name, this.email});
  final String id;
  final String? name;
  final String? email;

  factory ApiUser.fromJson(Map<String, Object?> json) => ApiUser(
    id: '${json['id']}',
    name: _nonEmpty(json['name']),
    email: _nonEmpty(json['email']),
  );

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'email': email};
}

String? _nonEmpty(Object? v) => v is String && v.isNotEmpty ? v : null;

/// A request body sent as it is (a photo), not as JSON.
class ApiBytes {
  const ApiBytes(this.bytes, this.contentType);
  final Uint8List bytes;
  final String contentType;
}

/// What every sign-in and refresh ends with.
class ApiSession {
  const ApiSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final ApiUser user;

  /// Throws [FormatException] when something is missing.
  factory ApiSession.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Not a session');
    final access = json['accessToken'];
    final refresh = json['refreshToken'];
    final expires = DateTime.tryParse('${json['expiresAt']}');
    final user = json['user'];
    if (access is! String ||
        refresh is! String ||
        expires == null ||
        user is! Map ||
        user['id'] == null) {
      throw const FormatException('Incomplete session');
    }
    return ApiSession(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: expires.toUtc(),
      user: ApiUser.fromJson(user.map((k, v) => MapEntry('$k', v))),
    );
  }

  Map<String, Object?> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': apiTime(expiresAt),
    'user': user.toJson(),
  };
}

/// One HTTP client for the whole Worker API.
///
/// Call [load] once at startup so [session] is ready before the first
/// screen. Signed-in calls get a fresh access token first: it's refreshed
/// when it has less than [refreshMargin] left, or after a 401, and the call
/// is then retried once. Refreshes that overlap share one trip, because each
/// refresh token works only once. If the Worker rejects the refresh token,
/// the session is cleared (signed out).
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this._db,
    http.Client? client,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 20),
  }) : _http = client ?? http.Client(),
       _clock = clock ?? DateTime.now;

  /// e.g. `https://setlist-tracker.example.workers.dev` (no trailing slash).
  final String baseUrl;
  final Duration timeout;
  final Database _db;
  final http.Client _http;
  final DateTime Function() _clock;

  static const refreshMargin = Duration(minutes: 2);

  /// Where the session is kept on the device.
  static final sessionStore = StoreRef<String, Object?>('backstage_session');
  static const _sessionKey = 'session';

  ApiSession? _session;
  final _changes = StreamController<ApiSession?>.broadcast();
  Future<bool>? _refreshing;

  /// Bumped on every sign-in and sign-out, so a refresh that finishes after
  /// the runner signed out can't sign them back in.
  int _generation = 0;

  ApiSession? get session => _session;

  /// Emits on every change: sign-in, refresh, sign-out.
  Stream<ApiSession?> get sessionChanges => _changes.stream;

  /// Reads the saved session, if any.
  Future<void> load() async {
    final raw = await sessionStore.record(_sessionKey).get(_db);
    if (raw == null) return;
    try {
      _session = ApiSession.fromJson(raw);
    } on FormatException {
      await sessionStore.record(_sessionKey).delete(_db);
    }
  }

  /// Saves [session] (from a sign-in) and tells everyone.
  Future<void> setSession(ApiSession session) async {
    _generation++;
    await _save(session);
  }

  /// Forgets the session on this device (signed out).
  Future<void> clearSession() async {
    _generation++;
    await _save(null);
  }

  Future<void> _save(ApiSession? session) async {
    final record = sessionStore.record(_sessionKey);
    if (session == null) {
      await record.delete(_db);
    } else {
      await record.put(_db, session.toJson());
    }
    _session = session;
    _changes.add(session);
  }

  // ---- JSON helpers ----

  Future<Object?> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) => send('GET', path, query: query, auth: auth);

  Future<Object?> post(String path, {Object? body, bool auth = true}) =>
      send('POST', path, body: body, auth: auth);

  Future<Object?> put(String path, {Object? body, bool auth = true}) =>
      send('PUT', path, body: body, auth: auth);

  Future<Object?> delete(String path, {bool auth = true}) =>
      send('DELETE', path, auth: auth);

  /// Sends one request and returns the decoded JSON (null for an empty
  /// answer such as a 204). Throws [ApiException] when the Worker says no;
  /// network trouble comes through as the http package's own exceptions.
  ///
  /// With [auth], the call needs a session: without one it fails with
  /// `not_signed_in` before anything is sent.
  Future<Object?> send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool auth = true,
  }) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...query});
    }
    if (!auth) return _decode(await _request(method, uri, body, null));
    return _decode(await _authed(method, uri, body));
  }

  /// Fetches [path] (which may carry its own query) as raw bytes, signed
  /// in. Throws [ApiException] like [send] when the Worker says no.
  Future<Uint8List> getBytes(String path) async {
    final res = await _authed('GET', Uri.parse('$baseUrl$path'), null);
    if (res.statusCode >= 200 && res.statusCode < 300) return res.bodyBytes;
    _decode(res);
    throw ApiException(res.statusCode, 'http_${res.statusCode}');
  }

  /// Sends a signed-in request, refreshing the token and retrying once
  /// after a 401.
  Future<http.Response> _authed(String method, Uri uri, Object? body) async {
    String? token = await _freshToken();
    var res = await _request(method, uri, body, token);
    if (res.statusCode == 401) {
      // Another call may have refreshed already; only refresh if the token
      // that was turned down is still the current one.
      if (_session?.accessToken == token && !await _refresh()) {
        throw const ApiException(401, 'not_signed_in', 'Signed out.');
      }
      token = _session?.accessToken;
      if (token == null) {
        throw const ApiException(401, 'not_signed_in', 'Signed out.');
      }
      res = await _request(method, uri, body, token);
    }
    return res;
  }

  Future<http.Response> _request(
    String method,
    Uri uri,
    Object? body,
    String? token,
  ) async {
    final req = http.Request(method, uri);
    req.headers['Accept'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body is ApiBytes) {
      req.headers['Content-Type'] = body.contentType;
      req.bodyBytes = body.bytes;
    } else if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    final streamed = await _http.send(req).timeout(timeout);
    return http.Response.fromStream(streamed).timeout(timeout);
  }

  Object? _decode(http.Response res) {
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    Object? json;
    if (res.body.isNotEmpty) {
      try {
        json = jsonDecode(res.body);
      } on FormatException {
        if (ok) rethrow;
      }
    }
    if (ok) return json;
    final error = json is Map ? json['error'] : null;
    final message = json is Map ? json['message'] : null;
    throw ApiException(
      res.statusCode,
      error is String ? error : 'http_${res.statusCode}',
      message is String ? message : '',
    );
  }

  /// The access token to send, refreshed first when it's nearly expired.
  Future<String> _freshToken() async {
    final s = _session;
    if (s == null) {
      throw const ApiException(401, 'not_signed_in', 'Sign in first.');
    }
    if (s.expiresAt.difference(_clock().toUtc()) > refreshMargin) {
      return s.accessToken;
    }
    if (!await _refresh()) {
      throw const ApiException(401, 'not_signed_in', 'Signed out.');
    }
    return _session!.accessToken;
  }

  /// Swaps the refresh token for a new session. All callers that arrive
  /// while one refresh is running wait for that same one.
  ///
  /// Returns false (and signs out) when the Worker turns the refresh token
  /// down. Network trouble or a server error is thrown instead and keeps the
  /// session, so a runner with no signal isn't signed out.
  Future<bool> _refresh() => _refreshing ??= _doRefresh().whenComplete(() {
    _refreshing = null;
  });

  Future<bool> _doRefresh() async {
    final s = _session;
    if (s == null) return false;
    final generation = _generation;
    final res = await _request('POST', Uri.parse('$baseUrl/api/auth/refresh'), {
      'refreshToken': s.refreshToken,
    }, null);
    if (generation != _generation) return _session != null;
    if (res.statusCode >= 400 && res.statusCode < 500) {
      await clearSession();
      return false;
    }
    final next = ApiSession.fromJson(_decode(res));
    await _save(next);
    return true;
  }
}
