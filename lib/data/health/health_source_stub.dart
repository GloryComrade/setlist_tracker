import 'health_source.dart';

/// Web: Apple Health doesn't exist here, and the plugin is never compiled in.
HealthSource createHealthSource() => const UnavailableHealthSource();
