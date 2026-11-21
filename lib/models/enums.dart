/// Fixed choice lists used across the app.
///
/// Each enum stores its [name] in the database (e.g. "studio"), so renaming a
/// label is safe but renaming an enum value needs a data migration.
library;

/// Studio Session (treadmill) or Live Show (outdoor).
enum Venue {
  studio('Studio Session', 'Treadmill'),
  live('Live Show', 'Outdoor');

  const Venue(this.label, this.subtitle);
  final String label;
  final String subtitle;

  static Venue fromName(String? name) =>
      Venue.values.firstWhere((v) => v.name == name, orElse: () => Venue.live);
}

enum WorkoutType {
  easy('Easy'),
  long('Headliner'),
  tempo('Tempo'),
  intervals('Intervals'),
  recovery('Recovery');

  const WorkoutType(this.label);
  final String label;

  static WorkoutType fromName(String? name) => WorkoutType.values
      .firstWhere((v) => v.name == name, orElse: () => WorkoutType.easy);
}

/// How the Show felt, from worst to best.
enum Feel {
  rough('😫', 'Rough night'),
  offKey('😕', 'Off key'),
  fine('😐', 'Fine'),
  good('🙂', 'Good set'),
  encore('🤩', 'Encore!');

  const Feel(this.emoji, this.label);
  final String emoji;
  final String label;

  static Feel fromName(String? name) =>
      Feel.values.firstWhere((v) => v.name == name, orElse: () => Feel.fine);
}

enum Surface {
  road('Road'),
  trail('Trail'),
  track('Track');

  const Surface(this.label);
  final String label;

  static Surface fromName(String? name) =>
      Surface.values.firstWhere((v) => v.name == name, orElse: () => Surface.road);
}

enum Conditions {
  clear('Clear', '☀️'),
  cloudy('Cloudy', '☁️'),
  rain('Rain', '🌧️'),
  snow('Snow', '❄️'),
  fog('Fog', '🌫️'),
  windy('Windy', '💨');

  const Conditions(this.label, this.emoji);
  final String label;
  final String emoji;

  static Conditions? fromName(String? name) {
    for (final c in Conditions.values) {
      if (c.name == name) return c;
    }
    return null;
  }
}
