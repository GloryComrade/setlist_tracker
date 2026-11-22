/// The drawn tour-art badges a runner can pick as their Crew picture.
///
/// The ids are what the server stores (AVATAR_BADGES in
/// backend/src/avatars.ts; a test keeps the two lists the same). The art
/// is drawn by `lib/ui/crew/avatar_badges.dart` in the runner's avatar color.
library;

/// Badge id → what a screen reader calls it, in picker order.
const kAvatarBadges = <String, String>{
  'mic': 'Microphone',
  'vinyl': 'Vinyl record',
  'guitar-pick': 'Guitar pick',
  'sneaker': 'Running shoe',
  'headphones': 'Headphones',
  'drumsticks': 'Drumsticks',
  'lightning': 'Lightning',
  'star': 'Star',
  'ticket': 'Ticket',
  'amp': 'Amp',
  'cassette': 'Cassette',
  'setlist': 'Setlist',
  'laurel': 'Laurel',
  'medal': 'Medal',
  'stopwatch': 'Stopwatch',
  'mountain': 'Mountain',
  'flame': 'Flame',
  'wave': 'Wave',
  'moon': 'Moon',
  'sun': 'Sun',
  'heart': 'Heart',
  'crown': 'Crown',
  'music-note': 'Music note',
  'spotlight': 'Spotlight',
};

bool isAvatarBadge(String? id) => id != null && kAvatarBadges.containsKey(id);
