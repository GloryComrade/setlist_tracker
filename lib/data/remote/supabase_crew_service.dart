import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/crew.dart';
import '../../models/json_utils.dart';
import '../crew/crew_service.dart';

/// [CrewService] backed by the Crew tables and functions in
/// `supabase/migrations/20261123000000_the_crew.sql`. Row Level Security on
/// the server decides who sees what; nothing here is trusted to.
class SupabaseCrewService implements CrewService {
  SupabaseCrewService(this._client);
  final SupabaseClient _client;

  String get _me {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const CrewException('Sign in to join the Crew.');
    return id;
  }

  /// Runs [call], turning the server's own messages into [CrewException].
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PostgrestException catch (e) {
      // The server's own words (supabase/migrations), said the app's way.
      const known = {
        'Pick a stage name first': 'Pick a stage name first.',
        'That is your own invite': 'That’s your own invite.',
        'Too many tries': 'Too many codes tried. Wait an hour, then try again.',
        "Can't block that runner": 'That runner can’t be blocked.',
        'Not signed in': 'Sign in to join the Crew.',
      };
      final hit = known.entries
          .where((k) => e.message.contains(k.key))
          .firstOrNull;
      throw CrewException(
        hit?.value ?? 'The Crew couldn’t be reached. Check your connection.',
      );
    }
  }

  CrewProfile _profile(Map<String, dynamic> r) => CrewProfile(
    userId: r['user_id'] as String,
    stageName: r['stage_name'] as String,
    color: asInt(r['color']),
    openingNight: parseDateOnly(r['opening_night']),
    tourName: asStringOrNull(r['tour_name']),
    alwaysShare: r['always_share'] == true,
    showOpeningNight: r['show_opening_night'] == true,
  );

  @override
  Future<CrewProfile?> myProfile() => _guard(() async {
    final r = await _client
        .from('crew_profiles')
        .select()
        .eq('user_id', _me)
        .maybeSingle();
    return r == null ? null : _profile(r);
  });

  @override
  Future<CrewProfile> saveProfile(CrewProfile p) => _guard(() async {
    final r = await _client
        .from('crew_profiles')
        .upsert({
          'user_id': _me,
          'stage_name': p.stageName.trim(),
          'color': p.color,
          'always_share': p.alwaysShare,
          'show_opening_night': p.showOpeningNight,
          'opening_night': p.showOpeningNight && p.openingNight != null
              ? dateOnlyString(p.openingNight!)
              : null,
          'tour_name': p.showOpeningNight ? p.tourName : null,
          'updated_at': utcString(DateTime.now()),
        }, onConflict: 'user_id')
        .select()
        .single();
    return _profile(r);
  });

  @override
  Future<String> inviteCode() =>
      _guard(() async => await _client.rpc('crew_invite_code') as String);

  @override
  Future<CrewInvitePreview?> previewInvite(String code) => _guard(() async {
    final rows = await _client.rpc(
      'crew_invite_preview',
      params: {'invite': code},
    );
    final r = rows is List && rows.isNotEmpty ? asMap(rows.first) : null;
    if (r == null) return null;
    return CrewInvitePreview(
      stageName: '${r['stage_name']}',
      color: asInt(r['color']),
      alreadyCrew: r['already_crew'] == true,
      ownInvite: r['own_invite'] == true,
    );
  });

  @override
  Future<void> join(String code) async {
    final who = await _guard(
      () => _client.rpc('join_crew', params: {'invite': code}),
    );
    if (who == null) {
      throw const CrewException('That invite has expired or doesn’t exist.');
    }
  }

  @override
  Future<List<CrewMate>> crew() => _guard(() async {
    final rows = await _client.rpc('my_crew') as List;
    return [
      for (final row in rows)
        if (asMap(row) case final r?)
          CrewMate(
            userId: '${r['user_id']}',
            stageName: '${r['stage_name']}',
            color: asInt(r['color']),
            since: parseDate(r['since']) ?? DateTime.now(),
            openingNight: parseDateOnly(r['opening_night']),
            tourName: asStringOrNull(r['tour_name']),
            blocked: r['blocked'] == true,
          ),
    ];
  });

  @override
  Future<void> leave(String userId) =>
      _guard(() => _client.rpc('leave_crew', params: {'other': userId}));

  @override
  Future<void> block(String userId) =>
      _guard(() => _client.rpc('block_crew', params: {'other': userId}));

  @override
  Future<void> unblock(String userId) =>
      _guard(() => _client.rpc('unblock_crew', params: {'other': userId}));

  @override
  Future<List<CrewPost>> feed() => _guard(() async {
    final me = _me;
    final reported = {
      for (final r in await _client.from('crew_reports').select('post_id'))
        '${r['post_id']}',
    };
    final rows = await _client
        .from('crew_posts')
        .select(
          'id, owner, show_id, data, created_at, '
          'crew_profiles(stage_name, color), crew_encores(user_id)',
        )
        .order('created_at', ascending: false)
        .limit(60);
    final out = <CrewPost>[];
    for (final r in rows) {
      final id = '${r['id']}';
      if (reported.contains(id)) continue;
      final profile = asMap(r['crew_profiles']) ?? const {};
      final cheers = asMapList(r['crew_encores']);
      out.add(
        CrewPost(
          id: id,
          ownerId: '${r['owner']}',
          stageName: asStringOrNull(profile['stage_name']) ?? 'Runner',
          color: asInt(profile['color']),
          showId: '${r['show_id']}',
          show: SharedShow.fromJson(asMap(r['data']) ?? const {}),
          sharedAt: parseDate(r['created_at'])?.toLocal() ?? DateTime.now(),
          encores: cheers.length,
          encoredByMe: cheers.any((c) => c['user_id'] == me),
          mine: r['owner'] == me,
        ),
      );
    }
    return out;
  });

  @override
  Future<Map<String, SharedInfo>> mySharedShows() => _guard(() async {
    final rows = await _client
        .from('crew_posts')
        .select('show_id, show_updated_at, data')
        .eq('owner', _me);
    return {
      for (final r in rows)
        '${r['show_id']}': SharedInfo(
          showUpdatedAt: DateTime.parse('${r['show_updated_at']}').toUtc(),
          includesNotes: asMap(r['data'])?['notes'] != null,
        ),
    };
  });

  @override
  Future<void> share(String showId, SharedShow show, DateTime showUpdatedAt) =>
      _guard(
        () => _client.from('crew_posts').upsert({
          'owner': _me,
          'show_id': showId,
          'data': show.toJson(),
          'show_updated_at': utcString(showUpdatedAt),
          'updated_at': utcString(DateTime.now()),
        }, onConflict: 'owner,show_id'),
      );

  @override
  Future<void> unshare(String showId) => _guard(
    () => _client
        .from('crew_posts')
        .delete()
        .eq('owner', _me)
        .eq('show_id', showId),
  );

  @override
  Future<void> encore(String postId, {required bool on}) => _guard(() async {
    if (on) {
      await _client.from('crew_encores').upsert({
        'post_id': postId,
        'user_id': _me,
      }, ignoreDuplicates: true);
    } else {
      await _client
          .from('crew_encores')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', _me);
    }
  });

  @override
  Future<void> report(CrewPost post, String reason) => _guard(
    () => _client.from('crew_reports').insert({
      'post_id': post.id,
      'reported_user': post.ownerId,
      'reason': reason,
    }),
  );
}
