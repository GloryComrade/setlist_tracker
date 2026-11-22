import 'package:flutter/foundation.dart' show debugPrint;

import '../../models/crew.dart';
import '../../models/json_utils.dart';
import '../crew/crew_service.dart';
import 'api_client.dart';

/// [CrewService] backed by the Worker's `/api/crew` routes
/// (docs/cloudflare-api.md). The Worker decides who sees what; nothing here
/// is trusted to.
class CloudflareCrewService implements CrewService {
  CloudflareCrewService(this._api);
  final ApiClient _api;

  static const unreachable =
      'The Crew couldn’t be reached. Check your connection.';

  /// The Worker's error codes, said the app's way.
  static const messages = {
    'need_stage_name': 'Pick a stage name first.',
    'invite_invalid': 'That invite has expired or doesn’t exist.',
    'own_invite': 'That’s your own invite.',
    'too_many_tries': 'Too many codes tried. Wait an hour, then try again.',
    'cant_block': 'That runner can’t be blocked.',
    'not_signed_in': 'Sign in to join the Crew.',
    'not_found': 'That Show isn’t in your Crew’s feed anymore.',
  };

  /// Runs [call], turning every failure into a [CrewException].
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on CrewException {
      rethrow;
    } on ApiException catch (e) {
      throw CrewException(messages[e.code] ?? unreachable);
    } catch (e) {
      debugPrint('Crew: $e');
      throw const CrewException(unreachable);
    }
  }

  static String _seg(String s) => Uri.encodeComponent(s);

  static Map<String, Object?> _map(Object? json) =>
      asMap(json) ?? (throw const FormatException('Expected an object'));

  CrewProfile _profile(Map<String, Object?> r) => CrewProfile(
    userId: '${r['userId']}',
    stageName: '${r['stageName']}',
    color: asInt(r['color']),
    allActivityPending: r['allActivityPending'] == true,
  );

  @override
  Future<CrewProfile?> myProfile() => _guard(() async {
    final r = asMap(await _api.get('/api/crew/profile'));
    return r == null ? null : _profile(r);
  });

  @override
  Future<CrewProfile> saveProfile(CrewProfile p) => _guard(() async {
    final r = await _api.put(
      '/api/crew/profile',
      body: {'stageName': p.stageName.trim(), 'color': p.color},
    );
    return _profile(_map(r));
  });

  @override
  Future<CrewProfile> acceptAllActivity(CrewProfile p) => _guard(() async {
    final r = await _api.put(
      '/api/crew/profile',
      body: {
        'stageName': p.stageName.trim(),
        'color': p.color,
        'allActivity': true,
      },
    );
    return _profile(_map(r));
  });

  @override
  Future<String> inviteCode() => _guard(() async {
    final r = _map(await _api.post('/api/crew/invite'));
    return '${r['code']}';
  });

  @override
  Future<CrewInvitePreview?> previewInvite(String code) => _guard(() async {
    final Object? json;
    try {
      json = await _api.get('/api/crew/invite/${_seg(code)}');
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
    final r = _map(json);
    return CrewInvitePreview(
      stageName: '${r['stageName']}',
      color: asInt(r['color']),
      alreadyCrew: r['alreadyCrew'] == true,
      ownInvite: r['ownInvite'] == true,
    );
  });

  @override
  Future<void> join(String code) =>
      _guard(() => _api.post('/api/crew/join', body: {'code': code}));

  @override
  Future<List<CrewMate>> crew() => _guard(() async {
    final r = _map(await _api.get('/api/crew/mates'));
    return asMapList(r['mates']).map(CrewMate.fromJson).toList();
  });

  @override
  Future<void> leave(String userId) =>
      _guard(() => _api.delete('/api/crew/mates/${_seg(userId)}'));

  @override
  Future<void> block(String userId) =>
      _guard(() => _api.post('/api/crew/blocks', body: {'userId': userId}));

  @override
  Future<void> unblock(String userId) =>
      _guard(() => _api.delete('/api/crew/blocks/${_seg(userId)}'));

  @override
  Future<List<CrewPost>> feed() => _guard(() async {
    final r = _map(await _api.get('/api/crew/feed'));
    return asMapList(r['posts']).map(CrewPost.fromJson).toList();
  });

  @override
  Future<CrewMateDetail?> mate(String userId) => _guard(() async {
    final Object? json;
    try {
      json = await _api.get('/api/crew/mates/${_seg(userId)}');
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
    return CrewMateDetail.fromJson(_map(json));
  });

  @override
  Future<void> encore(String postId, {required bool on}) => _guard(() {
    final path = '/api/crew/posts/${_seg(postId)}/encore';
    return on ? _api.put(path) : _api.delete(path);
  });

  @override
  Future<void> report(CrewPost post, String reason) => _guard(
    () => _api.post(
      '/api/crew/posts/${_seg(post.id)}/report',
      body: {'reason': reason},
    ),
  );

  // ---- Tour invites ----

  @override
  Future<List<String>> inviteToTour(String tourId, List<String> userIds) =>
      _guard(() async {
        final Object? json;
        try {
          json = await _api.post(
            '/api/crew/tour-invites',
            body: {'tourId': tourId, 'to': userIds},
          );
        } on ApiException catch (e) {
          // Recipients outside the Crew are skipped, so a 404 is the Tour.
          if (e.status == 404) throw const TourNotSyncedException();
          rethrow;
        }
        final r = _map(json);
        final invited = r['invited'];
        return [
          if (invited is List)
            for (final id in invited) '$id',
        ];
      });

  @override
  Future<List<CrewTourInvite>> tourInvites() => _guard(() async {
    final r = _map(await _api.get('/api/crew/tour-invites'));
    return [
      for (final m in asMapList(r['invites'])) ?CrewTourInvite.fromJson(m),
    ];
  });

  @override
  Future<void> dismissTourInvite(String id) => _guard(() async {
    try {
      await _api.delete('/api/crew/tour-invites/${_seg(id)}');
    } on ApiException catch (e) {
      // Already gone: nothing left to dismiss.
      if (e.status != 404) rethrow;
    }
  });
}
