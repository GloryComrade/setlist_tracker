import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:setlist_tracker/data/crew/crew_service.dart';
import 'package:setlist_tracker/data/remote/api_client.dart';
import 'package:setlist_tracker/data/remote/cloudflare_crew_service.dart';
import 'package:setlist_tracker/models/crew.dart';

const _base = 'https://api.example.dev';

void main() {
  late List<http.Request> sent;
  late Future<http.Response> Function(http.Request) handler;

  Future<CloudflareCrewService> service() async {
    sent = [];
    final db = await newDatabaseFactoryMemory().openDatabase(
      'a${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final api = ApiClient(
      baseUrl: _base,
      db: db,
      client: MockClient((req) async {
        sent.add(req);
        return handler(req);
      }),
    );
    await api.setSession(
      ApiSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        user: const ApiUser(id: 'u1'),
      ),
    );
    return CloudflareCrewService(api);
  }

  http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  final profile = {
    'userId': 'u1',
    'stageName': 'Ryan',
    'color': 1,
    'avatarBadge': 'vinyl',
    'avatarUrl': '/api/crew/avatar/u1?v=5',
  };

  test('profiles, mates and posts read the picture', () {
    final p = CrewProfile.fromJson(profile);
    expect(p.avatarBadge, 'vinyl');
    expect(p.avatarUrl, '/api/crew/avatar/u1?v=5');
    expect(p.copyWith(avatarUrl: null).avatarUrl, isNull);
    expect(p.copyWith(color: 2).avatarBadge, 'vinyl');
    final m = CrewMate.fromJson({...profile, 'since': '2026-11-01T00:00:00Z'});
    expect(m.avatarUrl, '/api/crew/avatar/u1?v=5');
    final post = CrewPost.fromJson({
      ...profile,
      'ownerId': 'u1',
      'showId': 's1',
      'show': {'id': 's1', 'date': '2026-11-21T07:30:00.000'},
    });
    expect(post.avatarBadge, 'vinyl');
    expect(post.withEncore(true).avatarUrl, post.avatarUrl);
    expect(post.withPicture(null, null).avatarBadge, isNull);
  });

  test('badge, upload, fetch, remove and report', () async {
    final s = await service();
    handler = (_) async => json(profile);

    await s.saveAvatarBadge(
      const CrewProfile(userId: 'u1', stageName: ' Ryan ', color: 1),
      'vinyl',
    );
    expect(sent.last.method, 'PUT');
    expect(jsonDecode(sent.last.body), {
      'stageName': 'Ryan',
      'color': 1,
      'avatarBadge': 'vinyl',
    });

    final jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 1, 2, 3]);
    final up = await s.uploadAvatar(jpeg);
    expect(up.avatarUrl, '/api/crew/avatar/u1?v=5');
    expect(sent.last.url.path, '/api/crew/avatar');
    expect(sent.last.headers['Content-Type'], 'image/jpeg');
    expect(sent.last.headers['Authorization'], 'Bearer access');
    expect(sent.last.bodyBytes, jpeg);

    handler = (_) async => http.Response.bytes(jpeg, 200);
    expect(await s.avatarBytes('/api/crew/avatar/u1?v=5'), jpeg);
    expect(sent.last.url.toString(), '$_base/api/crew/avatar/u1?v=5');

    handler = (_) async => json({...profile, 'avatarUrl': null});
    expect((await s.removeAvatar()).avatarUrl, isNull);
    expect(sent.last.method, 'DELETE');

    handler = (_) async => http.Response('', 204);
    await s.reportAvatar('u2', 'Not a runner');
    expect(sent.last.url.path, '/api/crew/report-avatar');
    expect(jsonDecode(sent.last.body), {
      'userId': 'u2',
      'reason': 'Not a runner',
    });
  });

  test('a photo the server turns down, and a missing one', () async {
    final s = await service();
    handler = (_) async =>
        json({'error': 'bad_request', 'message': 'too big'}, 413);
    await expectLater(
      s.uploadAvatar(Uint8List.fromList([0xff, 0xd8, 0xff])),
      throwsA(
        isA<CrewException>().having(
          (e) => e.message,
          'message',
          CloudflareCrewService.badPhoto,
        ),
      ),
    );
    handler = (_) async => json({'error': 'not_found', 'message': 'x'}, 404);
    await expectLater(
      s.avatarBytes('/api/crew/avatar/u2?v=1'),
      throwsA(isA<CrewException>()),
    );
  });
}
