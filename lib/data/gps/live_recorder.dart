/// Recording a Live Show with GPS: the state behind the On Stage screen.
///
/// The run in progress is saved on the device as it goes (every few fixes
/// and at every pause), so if iOS closes the app mid-run the Show can be
/// picked back up. An ended run waits there too until it's booked or
/// thrown away. Never synced.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import '../../logic/gps_math.dart';
import '../../models/gps_track.dart';
import '../providers.dart';
import 'location_source.dart';

abstract class RecordingStore {
  Future<LiveRecording?> load();
  Future<void> save(LiveRecording recording);
  Future<void> clear();
}

class SembastRecordingStore implements RecordingStore {
  SembastRecordingStore(this._db);
  final Database _db;

  static final _store = StoreRef<String, Object?>('live_recording');
  static const _key = 'current';

  @override
  Future<LiveRecording?> load() async {
    final raw = await _store.record(_key).get(_db);
    if (raw is! Map) return null;
    try {
      return LiveRecording.fromJson(raw.map((k, v) => MapEntry('$k', v)));
    } catch (e) {
      debugPrint('Live recording: $e');
      return null;
    }
  }

  @override
  Future<void> save(LiveRecording recording) =>
      _store.record(_key).put(_db, recording.toJson());

  @override
  Future<void> clear() => _store.record(_key).delete(_db);
}

class MemoryRecordingStore implements RecordingStore {
  LiveRecording? saved;

  @override
  Future<LiveRecording?> load() async =>
      saved == null ? null : LiveRecording.fromJson(saved!.toJson());

  @override
  Future<void> save(LiveRecording recording) async =>
      saved = LiveRecording.fromJson(recording.toJson());

  @override
  Future<void> clear() async => saved = null;
}

final locationSourceProvider = Provider<LocationSource>(
  (ref) => createLocationSource(),
);

final recordingStoreProvider = Provider<RecordingStore>(
  (ref) => SembastRecordingStore(ref.watch(databaseProvider)),
);

/// The wall clock the recorder reads. Tests swap it.
final recorderClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

enum RecorderPhase {
  /// Reading the saved run, if any.
  loading,

  /// Nothing recorded yet. The screen waits for "Go Live".
  ready,

  /// Asking for location access.
  starting,
  denied,
  servicesOff,
  recording,
  paused,

  /// Ended, waiting to be booked as a Show.
  ended,
}

@immutable
class RecorderState {
  const RecorderState({
    required this.phase,
    this.recording,
    this.now,
    this.lastAccuracyM,
  });

  final RecorderPhase phase;
  final LiveRecording? recording;

  /// The clock the screen reads, ticking once a second while recording.
  final DateTime? now;

  /// How good the latest fix was, for the GPS signal line.
  final double? lastAccuracyM;

  bool get hasRun => recording != null;
  bool get live =>
      phase == RecorderPhase.recording || phase == RecorderPhase.paused;

  RecorderState copyWith({
    RecorderPhase? phase,
    LiveRecording? recording,
    bool clearRecording = false,
    DateTime? now,
    double? lastAccuracyM,
  }) => RecorderState(
    phase: phase ?? this.phase,
    recording: clearRecording ? null : (recording ?? this.recording),
    now: now ?? this.now,
    lastAccuracyM: lastAccuracyM ?? this.lastAccuracyM,
  );
}

final liveRecorderProvider =
    NotifierProvider<LiveRecorderController, RecorderState>(
      LiveRecorderController.new,
    );

class LiveRecorderController extends Notifier<RecorderState> {
  StreamSubscription<GpsPoint>? _fixes;
  Timer? _ticker;
  int _unsaved = 0;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);

  DateTime clock() => ref.read(recorderClockProvider)();

  @override
  RecorderState build() {
    ref.onDispose(_stop);
    unawaited(_restore());
    return const RecorderState(phase: RecorderPhase.loading);
  }

  RecordingStore get _store => ref.read(recordingStoreProvider);
  LocationSource get _location => ref.read(locationSourceProvider);

  Future<void> _restore() async {
    LiveRecording? saved;
    try {
      saved = await _store.load();
    } catch (e) {
      debugPrint('Live recording: $e');
    }
    if (state.phase != RecorderPhase.loading) return;
    if (saved == null) {
      state = const RecorderState(phase: RecorderPhase.ready);
    } else if (saved.isEnded) {
      state = RecorderState(phase: RecorderPhase.ended, recording: saved);
    } else {
      // The app was closed mid-run. Hold it paused at the last fix (or the
      // last pause), so the time away doesn't count, and let the runner
      // resume or end it.
      if (!saved.isPaused) {
        saved.pause(
          saved.points.isEmpty
              ? saved.resumes.last
              : saved.points.last.fix.time,
        );
      }
      state = RecorderState(
        phase: RecorderPhase.paused,
        recording: saved,
        now: clock(),
      );
      await _save();
    }
  }

  /// Asks for location, then starts the clock and the GPS.
  Future<void> start() async {
    if (state.live || state.phase == RecorderPhase.starting) return;
    state = state.copyWith(phase: RecorderPhase.starting);
    final access = await _location.requestAccess();
    if (access != LocationAccess.granted) {
      state = state.copyWith(
        phase: access == LocationAccess.servicesOff
            ? RecorderPhase.servicesOff
            : RecorderPhase.denied,
      );
      return;
    }
    final now = clock();
    final rec = LiveRecording.start(now);
    state = RecorderState(
      phase: RecorderPhase.recording,
      recording: rec,
      now: now,
    );
    _listen();
    await _save();
  }

  void _listen() {
    _fixes ??= _location.fixes().listen(
      _onFix,
      onError: (Object e) => debugPrint('GPS: $e'),
    );
    _ticker ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => state = state.copyWith(now: clock()),
    );
  }

  void _stop() {
    _fixes?.cancel();
    _fixes = null;
    _ticker?.cancel();
    _ticker = null;
  }

  void _onFix(GpsPoint fix) {
    final rec = state.recording;
    if (rec == null || state.phase != RecorderPhase.recording) return;
    final kept = rec.addFix(fix);
    state = state.copyWith(
      recording: rec,
      now: clock(),
      lastAccuracyM: fix.accuracyM,
    );
    if (kept) _unsaved++;
    final since = clock().difference(_lastSave);
    if (_unsaved >= 10 || since.inSeconds >= 15) unawaited(_save());
  }

  Future<void> pause() async {
    final rec = state.recording;
    if (rec == null || state.phase != RecorderPhase.recording) return;
    rec.pause(clock());
    state = state.copyWith(phase: RecorderPhase.paused, recording: rec);
    await _save();
  }

  Future<void> resume() async {
    final rec = state.recording;
    if (rec == null || state.phase != RecorderPhase.paused) return;
    final access = await _location.requestAccess();
    if (access != LocationAccess.granted) return;
    rec.resume(clock());
    state = state.copyWith(
      phase: RecorderPhase.recording,
      recording: rec,
      now: clock(),
    );
    _listen();
    await _save();
  }

  /// Stops the GPS and keeps the run until it's booked.
  Future<void> end() async {
    final rec = state.recording;
    if (rec == null || !state.live) return;
    rec.end(clock());
    _stop();
    state = state.copyWith(phase: RecorderPhase.ended, recording: rec);
    await _save();
  }

  /// Throws the run away (after it's booked, or when the runner says so).
  Future<void> clear() async {
    _stop();
    state = const RecorderState(phase: RecorderPhase.ready);
    try {
      await _store.clear();
    } catch (e) {
      debugPrint('Live recording: $e');
    }
  }

  /// Back to "Go Live" after a refused location prompt.
  void reset() {
    if (!state.hasRun) state = const RecorderState(phase: RecorderPhase.ready);
  }

  Future<void> _save() async {
    final rec = state.recording;
    if (rec == null) return;
    _unsaved = 0;
    _lastSave = clock();
    try {
      await _store.save(rec);
    } catch (e) {
      debugPrint('Live recording: $e');
    }
  }
}
