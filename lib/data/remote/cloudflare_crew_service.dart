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
    openingNight: parseDateOnly(r['openingNight']),
    tourName: asStringOrNull(r['tourName']),
    alwaysShare: r['alwaysShare'] == true,
    showOpeningNight: r['showOpeningNight'] == true,
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
      body: {
        'stageName': p.stageName.trim(),
        'color': p.color,
        'alwaysShare': p.alwaysShare,
        'showOpeningNight': p.showOpeningNight,
        'openingNight': p.showOpeningNight && p.openingNight != null
            ? dateOnlyString(p.openingNight!)
            : null,
        'tourName': p.showOpeningNight ? p.tourName : null,
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
    return [
      for (final m in asMapList(r['mates']))
        CrewMate(
          userId: '${m['userId']}',
          stageName: '${m['stageName']}',
          color: asInt(m['color']),
          since: parseDate(m['since']) ?? DateTime.now(),
          openingNight: parseDateOnly(m['openingNight']),
          tourName: asStringOrNull(m['tourName']),
          blocked: m['blocked'] == true,
        ),
    ];
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
    return [
      for (final p in asMapList(r['posts']))
        CrewPost(
          id: '${p['id']}',
          ownerId: '${p['ownerId']}',
          stageName: asStringOrNull(p['stageName']) ?? 'Runner',
          color: asInt(p['color']),
          showId: '${p['showId']}',
          show: SharedShow.fromJson(asMap(p['show']) ?? const {}),
          sharedAt: parseDate(p['sharedAt'])?.toLocal() ?? DateTime.now(),
          encores: asInt(p['encores']),
          encoredByMe: p['encoredByMe'] == true,
          mine: p['mine'] == true,
        ),
    ];
  });

  @override
  Future<Map<String, SharedInfo>> mySharedShows() => _guard(() async {
    final shared = asMap(_map(await _api.get('/api/crew/shared'))['shared']);
    return {
      for (final MapEntry(:key, :value) in (shared ?? const {}).entries)
        if (asMap(value) case final info?)
          key: SharedInfo(
            showUpdatedAt: DateTime.parse('${info['showUpdatedAt']}').toUtc(),
            includesNotes: info['includesNotes'] == true,
          ),
    };
  });

  @override
  Future<void> share(String showId, SharedShow show, DateTime showUpdatedAt) =>
      _guard(
        () => _api.put(
          '/api/crew/shared/${_seg(showId)}',
          body: {
            'show': show.toJson(),
            'showUpdatedAt': apiTime(showUpdatedAt),
          },
        ),
      );

  @override
  Future<void> unshare(String showId) =>
      _guard(() => _api.delete('/api/crew/shared/${_seg(showId)}'));

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
}
