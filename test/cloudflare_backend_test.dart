import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:setlist_tracker/data/auth/auth_service.dart';
import 'package:setlist_tracker/data/crew/crew_service.dart';
import 'package:setlist_tracker/data/remote/api_client.dart';
import 'package:setlist_tracker/data/remote/cloudflare_auth_service.dart';
import 'package:setlist_tracker/data/remote/cloudflare_crew_service.dart';
import 'package:setlist_tracker/data/remote/cloudflare_remote_store.dart';
import 'package:setlist_tracker/data/sync/remote_store.dart';
import 'package:setlist_tracker/models/crew.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/models/show.dart';
import 'package:setlist_tracker/models/tour.dart';

const _base = 'https://api.test';
final _now = DateTime.utc(2026, 11, 22, 12);

Map<String, Object?> _sessionJson(
  String access, {
  String refresh = 'r1',
  DateTime? expiresAt,
  String? name = 'Ryan Cheng',
}) => {
  'accessToken': access,
  'refreshToken': refresh,
  'expiresAt': apiTime(expiresAt ?? _now.add(const Duration(hours: 1))),
  'user': {'id': 'u1', 'name': name, 'email': 'ryan@example.com'},
};

http.Response _json(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response _error(int status, String code) =>
    _json({'error': code, 'message': 'words'}, status);

/// A recorded request with its decoded body.
class _Sent {
  _Sent(this.req)
    : body = req.body.isEmpty ? null : jsonDecode(req.body) as Object?;
  final http.Request req;
  final Object? body;
  String get method => req.method;
  String get path => req.url.path;
  String? get auth => req.headers['Authorization'];
}

class _Harness {
  _Harness(this.db, this.handler);
  final Database db;
  Future<http.Response> Function(_Sent) handler;
  final sent = <_Sent>[];
  DateTime now = _now;

  late final api = ApiClient(
    baseUrl: _base,
    db: db,
    clock: () => now,
    client: MockClient((req) async {
      final s = _Sent(req);
      sent.add(s);
      return handler(s);
    }),
  );

  Future<void> signIn({String access = 'a1', DateTime? expiresAt}) =>
      api.setSession(
        ApiSession.fromJson(_sessionJson(access, expiresAt: expiresAt)),
      );
}

Future<_Harness> _harness(Future<http.Response> Function(_Sent) handler) async {
  final db = await newDatabaseFactoryMemory().openDatabase('t.db');
  return _Harness(db, handler);
}

void main() {
  group('resolveApiBaseUrl', () {
    final page = Uri.parse('https://setlist.example.com/app/?x=1#/shows');

    test('empty means no backend', () {
      expect(resolveApiBaseUrl('', isWeb: true, page: page), isNull);
      expect(resolveApiBaseUrl('  ', isWeb: false, page: page), isNull);
    });

    test('same-origin is the page origin on the web only', () {
      expect(
        resolveApiBaseUrl('same-origin', isWeb: true, page: page),
        'https://setlist.example.com',
      );
      expect(
        resolveApiBaseUrl(
          'same-origin',
          isWeb: true,
          page: Uri.parse('http://localhost:5000/'),
        ),
        'http://localhost:5000',
      );
      expect(
        resolveApiBaseUrl('same-origin', isWeb: false, page: page),
        isNull,
      );
    });

    test('a full address loses its trailing slash', () {
      expect(
        resolveApiBaseUrl(
          'https://setlist-tracker.x.workers.dev/',
          isWeb: false,
          page: page,
        ),
        'https://setlist-tracker.x.workers.dev',
      );
    });
  });

  test('apiTime is UTC with milliseconds', () {
    expect(
      apiTime(DateTime.utc(2026, 11, 22, 3, 4, 5, 678, 901)),
      '2026-11-22T03:04:05.678Z',
    );
    expect(apiTime(DateTime.utc(2026)), '2026-01-01T00:00:00.000Z');
  });

  group('ApiClient', () {
    test('keeps the session on the device across restarts', () async {
      final h = await _harness((_) async => _json({}));
      await h.signIn();
      final again = ApiClient(baseUrl: _base, db: h.db);
      await again.load();
      expect(again.session?.accessToken, 'a1');
      expect(again.session?.user.name, 'Ryan Cheng');
      await h.api.clearSession();
      final third = ApiClient(baseUrl: _base, db: h.db);
      await third.load();
      expect(third.session, isNull);
    });

    test('sends the bearer token and decodes JSON', () async {
      final h = await _harness((_) async => _json({'id': 'u1'}));
      await h.signIn();
      expect(await h.api.get('/api/me'), {'id': 'u1'});
      expect(h.sent.single.auth, 'Bearer a1');
      expect(h.sent.single.req.url.toString(), '$_base/api/me');
    });

    test('maps {error, message} to ApiException', () async {
      final h = await _harness(
        (_) async => _json({'error': 'bad_request', 'message': 'No.'}, 400),
      );
      await h.signIn();
      await expectLater(
        h.api.post('/api/crew/blocks', body: {'userId': 'x'}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 400)
              .having((e) => e.code, 'code', 'bad_request')
              .having((e) => e.message, 'message', 'No.'),
        ),
      );
    });

    test('signed-in calls without a session fail before sending', () async {
      final h = await _harness((_) async => _json({}));
      await expectLater(
        h.api.get('/api/me'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'not_signed_in'),
        ),
      );
      expect(h.sent, isEmpty);
    });

    test(
      'refreshes first when the token is within 2 minutes of expiry',
      () async {
        final h = await _harness((s) async {
          if (s.path == '/api/auth/refresh') {
            expect(s.body, {'refreshToken': 'r1'});
            return _json(_sessionJson('a2', refresh: 'r2'));
          }
          return _json({'ok': true});
        });
        await h.signIn(expiresAt: _now.add(const Duration(seconds: 90)));
        await h.api.get('/api/me');
        expect(h.sent.map((s) => s.path), ['/api/auth/refresh', '/api/me']);
        expect(h.sent.first.auth, isNull);
        expect(h.sent.last.auth, 'Bearer a2');
        expect(h.api.session?.refreshToken, 'r2');
      },
    );

    test('a token with time left is not refreshed', () async {
      final h = await _harness((_) async => _json({}));
      await h.signIn(expiresAt: _now.add(const Duration(minutes: 3)));
      await h.api.get('/api/me');
      expect(h.sent.map((s) => s.path), ['/api/me']);
    });

    test('after a 401 it refreshes and retries once', () async {
      var meCalls = 0;
      final h = await _harness((s) async {
        if (s.path == '/api/auth/refresh') {
          return _json(_sessionJson('a2', refresh: 'r2'));
        }
        meCalls++;
        return s.auth == 'Bearer a2'
            ? _json({'id': 'u1'})
            : _error(401, 'not_signed_in');
      });
      await h.signIn();
      expect(await h.api.get('/api/me'), {'id': 'u1'});
      expect(meCalls, 2);
      expect(h.sent.map((s) => s.path), [
        '/api/me',
        '/api/auth/refresh',
        '/api/me',
      ]);
    });

    test('a second 401 after the retry is thrown, not retried again', () async {
      final h = await _harness((s) async {
        if (s.path == '/api/auth/refresh') {
          return _json(_sessionJson('a2', refresh: 'r2'));
        }
        return _error(401, 'not_signed_in');
      });
      await h.signIn();
      await expectLater(h.api.get('/api/me'), throwsA(isA<ApiException>()));
      expect(h.sent.where((s) => s.path == '/api/me'), hasLength(2));
      expect(h.sent.where((s) => s.path == '/api/auth/refresh'), hasLength(1));
    });

    test('concurrent calls share one in-flight refresh', () async {
      final gate = Completer<void>();
      var refreshes = 0;
      final h = await _harness((s) async {
        if (s.path == '/api/auth/refresh') {
          refreshes++;
          await gate.future;
          return _json(_sessionJson('a2', refresh: 'r2'));
        }
        return _json({'path': s.path});
      });
      await h.signIn(expiresAt: _now.add(const Duration(seconds: 30)));
      final calls = [
        h.api.get('/api/crew/feed'),
        h.api.get('/api/crew/mates'),
        h.api.get('/api/crew/shared'),
      ];
      await pumpEventQueue();
      gate.complete();
      await Future.wait(calls);
      expect(refreshes, 1);
      expect(
        h.sent.where((s) => s.path != '/api/auth/refresh').map((s) => s.auth),
        everyElement('Bearer a2'),
      );
    });

    test('concurrent 401s share one refresh too', () async {
      final gate = Completer<void>();
      var refreshes = 0;
      final h = await _harness((s) async {
        if (s.path == '/api/auth/refresh') {
          refreshes++;
          await gate.future;
          return _json(_sessionJson('a2', refresh: 'r2'));
        }
        return s.auth == 'Bearer a2' ? _json({}) : _error(401, 'not_signed_in');
      });
      await h.signIn();
      final calls = [h.api.get('/api/me'), h.api.get('/api/crew/feed')];
      await pumpEventQueue();
      gate.complete();
      await Future.wait(calls);
      expect(refreshes, 1);
    });

    test('a refused refresh signs out', () async {
      final h = await _harness((s) async {
        if (s.path == '/api/auth/refresh') return _error(401, 'not_signed_in');
        return _error(401, 'not_signed_in');
      });
      await h.signIn();
      final changes = <ApiSession?>[];
      final sub = h.api.sessionChanges.listen(changes.add);
      await expectLater(
        h.api.get('/api/me'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'not_signed_in'),
        ),
      );
      await pumpEventQueue();
      expect(h.api.session, isNull);
      expect(changes, [null]);
      final reloaded = ApiClient(baseUrl: _base, db: h.db);
      await reloaded.load();
      expect(reloaded.session, isNull);
      await sub.cancel();
    });

    test('a refresh that fails on the network keeps the session', () async {
      final h = await _harness((s) async {
        if (s.path == '/api/auth/refresh') {
          throw http.ClientException('offline');
        }
        return _json({});
      });
      await h.signIn(expiresAt: _now.add(const Duration(seconds: 10)));
      await expectLater(
        h.api.get('/api/me'),
        throwsA(isA<http.ClientException>()),
      );
      expect(h.api.session?.accessToken, 'a1');
    });
  });

  group('CloudflareAuthService', () {
    test('the iPhone browser flow exchanges the login code', () async {
      final h = await _harness((s) async {
        if (s.path == '/api/auth/exchange') {
          expect(s.body, {'code': 'abc123'});
          expect(s.auth, isNull);
          return _json(_sessionJson('a1'));
        }
        return _json({});
      });
      String? opened;
      String? scheme;
      final auth = CloudflareAuthService(
        h.api,
        isWeb: false,
        onIPhone: true,
        openSheet: (url, s) async {
          opened = url;
          scheme = s;
          return 'com.glorycomrade.setlisttracker://login-callback'
              '?login_code=abc123';
        },
      );
      final holders = <PassHolder?>[];
      final sub = auth.changes().listen(holders.add);
      await auth.signInWithGoogle();
      await pumpEventQueue();

      final start = Uri.parse(opened!);
      expect(start.path, '/api/auth/google/start');
      expect(
        start.queryParameters['return'],
        'com.glorycomrade.setlisttracker://login-callback',
      );
      expect(scheme, 'com.glorycomrade.setlisttracker');
      expect(auth.current?.id, 'u1');
      expect(auth.current?.displayName, 'Ryan Cheng');
      expect(holders.single?.email, 'ryan@example.com');
      await sub.cancel();
    });

    test('closing the sheet is not an error', () async {
      final h = await _harness((_) async => _json({}));
      final auth = CloudflareAuthService(
        h.api,
        isWeb: false,
        onIPhone: true,
        openSheet: (_, _) async => throw PlatformException(code: 'CANCELED'),
      );
      await auth.signInWithGoogle();
      expect(auth.current, isNull);
      expect(h.sent, isEmpty);
    });

    test('a login_error comes back as an error', () async {
      final h = await _harness((_) async => _json({}));
      final auth = CloudflareAuthService(
        h.api,
        isWeb: false,
        onIPhone: true,
        openSheet: (_, _) async =>
            'com.glorycomrade.setlisttracker://login-callback'
            '?login_error=access_denied',
      );
      await expectLater(
        auth.signInWithGoogle(),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'access_denied'),
        ),
      );
      expect(h.sent, isEmpty);
    });

    test('web startup exchanges login_code and cleans the address', () async {
      final h = await _harness((_) async => _json(_sessionJson('a1')));
      final auth = CloudflareAuthService(h.api, isWeb: true);
      final cleaned = await auth.completeSignInFrom(
        Uri.parse('https://setlist.example.com/app/?login_code=xyz&keep=1'),
      );
      expect(h.sent.single.path, '/api/auth/exchange');
      expect(h.sent.single.body, {'code': 'xyz'});
      expect(cleaned.toString(), 'https://setlist.example.com/app/?keep=1');
      expect(auth.current?.id, 'u1');
    });

    test('web startup without a code does nothing', () async {
      final h = await _harness((_) async => _json({}));
      final auth = CloudflareAuthService(h.api, isWeb: true);
      expect(
        await auth.completeSignInFrom(Uri.parse('https://x.test/#/shows')),
        isNull,
      );
      expect(h.sent, isEmpty);
    });

    test('a login_error on the web is cleared, still signed out', () async {
      final h = await _harness((_) async => _json({}));
      final auth = CloudflareAuthService(h.api, isWeb: true);
      final cleaned = await auth.completeSignInFrom(
        Uri.parse('http://localhost:5000/?login_error=denied'),
      );
      expect(cleaned.toString(), 'http://localhost:5000/');
      expect(h.sent, isEmpty);
      expect(auth.current, isNull);
    });

    test('a failed exchange leaves the runner signed out', () async {
      final h = await _harness((_) async => _error(400, 'bad_request'));
      final auth = CloudflareAuthService(h.api, isWeb: true);
      final cleaned = await auth.completeSignInFrom(
        Uri.parse('https://x.test/?login_code=old'),
      );
      expect(cleaned.toString(), 'https://x.test/');
      expect(auth.current, isNull);
    });

    test('native Apple sends the token, code, raw nonce and name', () async {
      final h = await _harness((_) async => _json(_sessionJson('a1')));
      final auth = CloudflareAuthService(h.api, isWeb: false, onIPhone: true);
      await auth.signInWithAppleCredential(
        identityToken: 'id-token',
        authorizationCode: 'auth-code',
        rawNonce: 'nonce',
        givenName: 'Ryan',
        familyName: null,
      );
      expect(h.sent.single.path, '/api/auth/apple/native');
      expect(h.sent.single.body, {
        'identityToken': 'id-token',
        'authorizationCode': 'auth-code',
        'rawNonce': 'nonce',
        'givenName': 'Ryan',
        'familyName': null,
      });
      expect(auth.current?.id, 'u1');
    });

    test('Apple off the iPhone uses the browser flow', () async {
      final h = await _harness((_) async => _json(_sessionJson('a1')));
      String? opened;
      final auth = CloudflareAuthService(
        h.api,
        isWeb: false,
        onIPhone: false,
        openSheet: (url, _) async {
          opened = url;
          return 'com.glorycomrade.setlisttracker://login-callback?login_code=c';
        },
      );
      await auth.signInWithApple();
      expect(Uri.parse(opened!).path, '/api/auth/apple/start');
      expect(auth.current, isNotNull);
    });

    test('sign out tells the Worker, then forgets the session', () async {
      final h = await _harness((_) async => http.Response('', 204));
      await h.signIn();
      final auth = CloudflareAuthService(h.api, isWeb: false);
      await auth.signOut();
      expect(h.sent.single.method, 'POST');
      expect(h.sent.single.path, '/api/auth/signout');
      expect(h.sent.single.body, {'refreshToken': 'r1'});
      expect(auth.current, isNull);
    });

    test('sign out offline still signs out on this device', () async {
      final h = await _harness((_) async => throw http.ClientException('x'));
      await h.signIn();
      final auth = CloudflareAuthService(h.api, isWeb: false);
      await auth.signOut();
      expect(auth.current, isNull);
    });

    test('delete account calls DELETE /api/me, then signs out', () async {
      final h = await _harness((_) async => http.Response('', 204));
      await h.signIn();
      final auth = CloudflareAuthService(h.api, isWeb: false);
      await auth.deleteAccount();
      expect(h.sent.single.method, 'DELETE');
      expect(h.sent.single.path, '/api/me');
      expect(h.sent.single.auth, 'Bearer a1');
      expect(auth.current, isNull);
    });

    test('a failed delete keeps the session', () async {
      final h = await _harness((_) async => _error(502, 'upstream'));
      await h.signIn();
      final auth = CloudflareAuthService(h.api, isWeb: false);
      await expectLater(auth.deleteAccount(), throwsA(isA<ApiException>()));
      expect(auth.current, isNotNull);
    });

    test('a token refresh does not look like a new sign-in', () async {
      final h = await _harness((s) async {
        if (s.path == '/api/auth/refresh') {
          return _json(_sessionJson('a2', refresh: 'r2'));
        }
        return _json({});
      });
      final auth = CloudflareAuthService(h.api, isWeb: false);
      final holders = <PassHolder?>[];
      final sub = auth.changes().listen(holders.add);
      await h.signIn(expiresAt: _now.add(const Duration(seconds: 5)));
      await h.api.get('/api/me');
      await pumpEventQueue();
      expect(holders, hasLength(1));
      await sub.cancel();
    });
  });

  group('CloudflareRemoteStore', () {
    test('upsert posts rows to /api/sync/{table}', () async {
      final h = await _harness((_) async => _json({'ok': true}));
      await h.signIn();
      await CloudflareRemoteStore(h.api).upsert('shows', [
        RemoteRow(
          id: 's1',
          data: const {'id': 's1', 'distanceMiles': 3.1},
          updatedAt: DateTime.utc(2026, 11, 22, 3, 4, 5, 678, 9),
          syncedAt: DateTime.utc(2026),
        ),
        RemoteRow(
          id: 's2',
          data: const {},
          updatedAt: DateTime.utc(2026, 11, 22),
          deletedAt: DateTime.utc(2026, 11, 23),
          syncedAt: DateTime.utc(2026),
        ),
      ]);
      final s = h.sent.single;
      expect(s.method, 'POST');
      expect(s.path, '/api/sync/shows');
      expect(s.body, {
        'rows': [
          {
            'id': 's1',
            'data': {'id': 's1', 'distanceMiles': 3.1},
            'updatedAt': '2026-11-22T03:04:05.678Z',
            'deletedAt': null,
          },
          {
            'id': 's2',
            'data': <String, Object?>{},
            'updatedAt': '2026-11-22T00:00:00.000Z',
            'deletedAt': '2026-11-23T00:00:00.000Z',
          },
        ],
      });
    });

    test('upsert sends nothing for no rows and splits at 500', () async {
      final h = await _harness((_) async => _json({'ok': true}));
      await h.signIn();
      final store = CloudflareRemoteStore(h.api);
      await store.upsert('gear', const []);
      expect(h.sent, isEmpty);
      await store.upsert('gear', [
        for (var i = 0; i < 501; i++)
          RemoteRow(id: 'g$i', data: const {}, updatedAt: _now, syncedAt: _now),
      ]);
      expect(h.sent, hasLength(2));
      expect(((h.sent[0].body as Map)['rows'] as List), hasLength(500));
      expect(((h.sent[1].body as Map)['rows'] as List), hasLength(1));
    });

    test('upsert treats a 409 (row owned by someone else) as done', () async {
      final h = await _harness(
        (_) async => _json({
          'error': 'bad_request',
          'message': 'Some rows belong to another runner.',
          'rejected': ['s1'],
        }, 409),
      );
      await h.signIn();
      await CloudflareRemoteStore(h.api).upsert('shows', [
        RemoteRow(id: 's1', data: const {}, updatedAt: _now, syncedAt: _now),
      ]);
      expect(h.sent, hasLength(1));
    });

    test('pullSince reads rows with since, offset and limit', () async {
      final h = await _harness(
        (_) async => _json({
          'rows': [
            {
              'id': 't1',
              'data': {'name': 'Spring Tour'},
              'updatedAt': '2026-11-20T10:00:00.000Z',
              'deletedAt': null,
              'syncedAt': '2026-11-21T10:00:00.123Z',
            },
            {
              'id': 't2',
              'data': {},
              'updatedAt': '2026-11-20T10:00:00.000Z',
              'deletedAt': '2026-11-20T11:00:00.000Z',
              'syncedAt': '2026-11-21T10:00:00.124Z',
            },
          ],
        }),
      );
      await h.signIn();
      final rows = await CloudflareRemoteStore(
        h.api,
      ).pullSince('tours', DateTime.utc(2026, 11, 1), offset: 500, limit: 500);
      final s = h.sent.single;
      expect(s.method, 'GET');
      expect(s.path, '/api/sync/tours');
      expect(s.req.url.queryParameters, {
        'since': '2026-11-01T00:00:00.000Z',
        'offset': '500',
        'limit': '500',
      });
      expect(rows.map((r) => r.id), ['t1', 't2']);
      expect(rows.first.data, {'name': 'Spring Tour'});
      expect(rows.first.deletedAt, isNull);
      expect(rows.first.syncedAt, DateTime.utc(2026, 11, 21, 10, 0, 0, 123));
      expect(rows.last.deletedAt, DateTime.utc(2026, 11, 20, 11));
    });

    test('pullSince without a cursor leaves since out', () async {
      final h = await _harness((_) async => _json({'rows': []}));
      await h.signIn();
      expect(
        await CloudflareRemoteStore(h.api).pullSince('gear', null),
        isEmpty,
      );
      expect(
        h.sent.single.req.url.queryParameters.containsKey('since'),
        isFalse,
      );
    });
  });

  group('CloudflareCrewService', () {
    Future<(CloudflareCrewService, _Harness)> crew(
      Future<http.Response> Function(_Sent) handler,
    ) async {
      final h = await _harness(handler);
      await h.signIn();
      return (CloudflareCrewService(h.api), h);
    }

    final profileJson = {
      'userId': 'u1',
      'stageName': 'Ryan',
      'color': 2,
      // Old fields an older server may still send are ignored.
      'alwaysShare': true,
    };

    test('profile: GET reads it, null when there is none', () async {
      final (s, h) = await crew((_) async => _json(profileJson));
      final p = await s.myProfile();
      expect(h.sent.single.path, '/api/crew/profile');
      expect(p?.stageName, 'Ryan');
      expect(p?.color, 2);
      h.handler = (_) async => http.Response('null', 200);
      expect(await s.myProfile(), isNull);
    });

    test('profile: PUT sends the contract body', () async {
      final (s, h) = await crew((_) async => _json(profileJson));
      await s.saveProfile(
        const CrewProfile(userId: 'u1', stageName: '  Ryan  ', color: 2),
      );
      expect(h.sent.single.method, 'PUT');
      expect(h.sent.single.body, {'stageName': 'Ryan', 'color': 2});
    });

    test('profile: allActivityPending, and OK-ing every Show', () async {
      final (s, h) = await crew(
        (r) async =>
            _json({...profileJson, 'allActivityPending': r.method == 'GET'}),
      );
      expect((await s.myProfile())?.allActivityPending, isTrue);
      h.handler = (_) async => _json(profileJson);
      expect((await s.myProfile())?.allActivityPending, isFalse);
      h.sent.clear();
      h.handler = (_) async =>
          _json({...profileJson, 'allActivityPending': false});
      final p = await s.acceptAllActivity(
        const CrewProfile(
          userId: 'u1',
          stageName: 'Ryan',
          color: 2,
          allActivityPending: true,
        ),
      );
      expect(h.sent.single.method, 'PUT');
      expect(h.sent.single.path, '/api/crew/profile');
      expect(h.sent.single.body, {
        'stageName': 'Ryan',
        'color': 2,
        'allActivity': true,
      });
      expect(p.allActivityPending, isFalse);
    });

    test('invite code, preview and join', () async {
      final (s, h) = await crew((r) async {
        switch (r.path) {
          case '/api/crew/invite':
            return _json({'code': 'ABCD2345'});
          case '/api/crew/invite/ABCD2345':
            return _json({
              'stageName': 'Sam',
              'color': 1,
              'alreadyCrew': false,
              'ownInvite': false,
            });
          case '/api/crew/join':
            return _json({'userId': 'u2'});
        }
        return _error(404, 'not_found');
      });
      expect(await s.inviteCode(), 'ABCD2345');
      expect(h.sent.last.method, 'POST');
      final preview = await s.previewInvite('ABCD2345');
      expect(preview?.stageName, 'Sam');
      expect(preview?.color, 1);
      expect(h.sent.last.method, 'GET');
      await s.join('ABCD2345');
      expect(h.sent.last.method, 'POST');
      expect(h.sent.last.body, {'code': 'ABCD2345'});
    });

    test('previewInvite is null on a 404', () async {
      final (s, _) = await crew((_) async => _error(404, 'invite_invalid'));
      expect(await s.previewInvite('ZZZZZZZZ'), isNull);
    });

    test('mates, leave, block and unblock', () async {
      final (s, h) = await crew((r) async {
        if (r.path == '/api/crew/mates' && r.method == 'GET') {
          return _json({
            'mates': [
              {
                'userId': 'u2',
                'stageName': 'Sam',
                'color': 1,
                'since': '2026-11-01T00:00:00.000Z',
                'tour': null,
                'blocked': false,
              },
              {
                'userId': 'u3',
                'stageName': 'Kit',
                'color': 3,
                'since': '2026-10-01T00:00:00.000Z',
                'tour': {
                  'id': 't3',
                  'name': 'Houston',
                  'raceDate': '2027-01-02',
                  'raceDistance': 'half',
                  'featuring': null,
                },
                'blocked': true,
              },
            ],
          });
        }
        return http.Response('', 204);
      });
      final mates = await s.crew();
      expect(mates.map((m) => m.userId), ['u2', 'u3']);
      expect(mates.last.blocked, isTrue);
      expect(mates.first.tour, isNull);
      expect(mates.last.tour?.raceDate, DateTime(2027, 1, 2));
      expect(mates.last.tour?.raceDistance, RaceDistance.half);
      expect(mates.last.tour?.name, 'Houston');
      expect(mates.first.since, DateTime.utc(2026, 11));

      await s.leave('u2');
      expect(
        (h.sent.last.method, h.sent.last.path),
        ('DELETE', '/api/crew/mates/u2'),
      );
      await s.block('u3');
      expect(
        (h.sent.last.method, h.sent.last.path),
        ('POST', '/api/crew/blocks'),
      );
      expect(h.sent.last.body, {'userId': 'u3'});
      await s.unblock('u3');
      expect(
        (h.sent.last.method, h.sent.last.path),
        ('DELETE', '/api/crew/blocks/u3'),
      );
    });

    Show crewShow(String id, double miles) => Show(
      id: id,
      date: DateTime(2026, 11, 20, 7, 30),
      venue: Venue.values.first,
      workoutType: WorkoutType.values.first,
      distanceMiles: miles,
      durationSeconds: 3000,
      effort: 7,
      feel: Feel.good,
      notes: 'Windy',
      createdAt: DateTime.utc(2026, 11, 20),
      updatedAt: DateTime.utc(2026, 11, 20),
    );

    Map<String, Object?> postJson(Show show) => {
      'id': 'u2:${show.id}',
      'ownerId': 'u2',
      'stageName': 'Sam',
      'color': 1,
      'showId': show.id,
      'show': show.toJson(),
      'gearName': 'Pegasus 41',
      'sharedAt': '2026-11-21T08:00:00.000Z',
      'encores': 3,
      'encoredByMe': true,
      'mine': false,
    };

    test('feed: whole Shows with Gear names', () async {
      final (s, h) = await crew(
        (r) async => _json({
          'posts': [postJson(crewShow('s9', 6.2))],
        }),
      );
      final post = (await s.feed()).single;
      expect(h.sent.single.path, '/api/crew/feed');
      expect(post.id, 'u2:s9');
      expect(post.ownerId, 'u2');
      expect(post.showId, 's9');
      expect(post.show.distanceMiles, 6.2);
      expect(post.show.effort, 7);
      expect(post.show.notes, 'Windy');
      expect(post.gearName, 'Pegasus 41');
      expect(post.encores, 3);
      expect(post.encoredByMe, isTrue);
      expect(post.mine, isFalse);
      expect(post.sharedAt, DateTime.utc(2026, 11, 21, 8).toLocal());
    });

    test('a mate’s page; null when they aren’t in your Crew', () async {
      final tour = Tour(
        id: 't1',
        name: 'Spring Tour',
        setup: TourSetup(
          raceDate: DateTime(2027, 4, 18),
          raceDistance: RaceDistance.half,
          goal: TourGoal.finish,
          currentWeeklyMiles: 20,
          longestRecentRunMiles: 8,
          daysPerWeek: 4,
          headlinerWeekday: 7,
          venuePreference: VenuePreference.mix,
        ),
        weeks: const [],
        createdAt: DateTime.utc(2026, 11),
        updatedAt: DateTime.utc(2026, 11),
      );
      final (s, h) = await crew((r) async {
        if (r.path == '/api/crew/mates/u2') {
          return _json({
            'mate': {
              'userId': 'u2',
              'stageName': 'Sam',
              'color': 1,
              'since': '2026-11-01T00:00:00.000Z',
            },
            'tour': tour.toJson(),
            'shows': [postJson(crewShow('a', 3)), postJson(crewShow('b', 5))],
          });
        }
        return _error(404, 'not_found');
      });
      final page = await s.mate('u2');
      expect(h.sent.last.method, 'GET');
      expect(page?.mate.stageName, 'Sam');
      expect(page?.tour?.name, 'Spring Tour');
      expect(page?.tour?.setup.raceDistance, RaceDistance.half);
      expect(page?.shows.map((p) => p.showId), ['a', 'b']);
      expect(await s.mate('u9'), isNull);
    });

    test('encore and report use "<ownerId>:<showId>" post ids', () async {
      final (s, h) = await crew((_) async => http.Response('', 204));
      await s.encore('u2:s9', on: true);
      expect(
        (h.sent.last.method, h.sent.last.path),
        ('PUT', '/api/crew/posts/u2%3As9/encore'),
      );
      await s.encore('u2:s9', on: false);
      expect(
        (h.sent.last.method, h.sent.last.path),
        ('DELETE', '/api/crew/posts/u2%3As9/encore'),
      );
      await s.report(
        CrewPost(
          id: 'u2:s9',
          ownerId: 'u2',
          stageName: 'Sam',
          color: 1,
          show: crewShow('s9', 3.1),
          sharedAt: _now,
        ),
        'Spam',
      );
      expect(
        (h.sent.last.method, h.sent.last.path),
        ('POST', '/api/crew/posts/u2%3As9/report'),
      );
      expect(h.sent.last.body, {'reason': 'Spam'});
    });

    test('error codes become the runner-facing messages', () async {
      const expected = {
        'need_stage_name': 'Pick a stage name first.',
        'invite_invalid': 'That invite has expired or doesn’t exist.',
        'own_invite': 'That’s your own invite.',
        'too_many_tries': 'Too many codes tried. Wait an hour, then try again.',
        'cant_block': 'That runner can’t be blocked.',
        'not_signed_in': 'Sign in to join the Crew.',
        'upstream': 'The Crew couldn’t be reached. Check your connection.',
        'bad_request': 'The Crew couldn’t be reached. Check your connection.',
      };
      const status = {
        'need_stage_name': 409,
        'invite_invalid': 404,
        'own_invite': 409,
        'too_many_tries': 429,
        'cant_block': 400,
        'not_signed_in': 401,
        'upstream': 502,
        'bad_request': 400,
      };
      for (final MapEntry(key: code, value: message) in expected.entries) {
        final (s, _) = await crew((r) async {
          if (r.path == '/api/auth/refresh') {
            return _error(401, 'not_signed_in');
          }
          return _error(status[code]!, code);
        });
        await expectLater(
          s.join('ABCD2345'),
          throwsA(
            isA<CrewException>().having((e) => e.message, 'message', message),
          ),
          reason: code,
        );
      }
    });

    test('network trouble and signed-out calls get runner words', () async {
      final (s, _) = await crew((_) async => throw http.ClientException('x'));
      await expectLater(
        s.feed(),
        throwsA(
          isA<CrewException>().having(
            (e) => e.message,
            'message',
            'The Crew couldn’t be reached. Check your connection.',
          ),
        ),
      );
      final h = await _harness((_) async => _json({}));
      await expectLater(
        CloudflareCrewService(h.api).myProfile(),
        throwsA(
          isA<CrewException>().having(
            (e) => e.message,
            'message',
            'Sign in to join the Crew.',
          ),
        ),
      );
    });
  });
}
