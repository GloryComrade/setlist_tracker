/// Where GPS fixes come from.
///
/// The recorder only sees [LocationSource] and plain [GpsPoint]s, so its
/// screen and tests never touch the plugin. iPhone only: the website can't
/// keep recording with the screen locked, so it doesn't offer Go Live.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/gps_track.dart';

enum LocationAccess {
  /// Allowed while the app is in use (enough, with the background mode on,
  /// to keep recording with the screen locked).
  granted,

  /// Refused. Only Settings can turn it back on.
  denied,

  /// Location Services are off for the whole phone.
  servicesOff,
}

abstract class LocationSource {
  bool get available;

  /// Shows Apple's "Allow While Using App" prompt the first time.
  Future<LocationAccess> requestAccess();

  /// Fixes as they arrive. Keeps going in the background on iPhone, with
  /// the blue location pill showing.
  Stream<GpsPoint> fixes();

  /// Opens this app's page in the Settings app.
  Future<void> openSettings();
}

class UnavailableLocationSource implements LocationSource {
  const UnavailableLocationSource();

  @override
  bool get available => false;

  @override
  Future<LocationAccess> requestAccess() async => LocationAccess.denied;

  @override
  Stream<GpsPoint> fixes() => const Stream.empty();

  @override
  Future<void> openSettings() async {}
}

/// iPhone GPS through the `geolocator` plugin.
class DeviceLocationSource implements LocationSource {
  const DeviceLocationSource();

  @override
  bool get available => true;

  @override
  Future<LocationAccess> requestAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.servicesOff;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    return switch (p) {
      LocationPermission.always ||
      LocationPermission.whileInUse => LocationAccess.granted,
      _ => LocationAccess.denied,
    };
  }

  @override
  Stream<GpsPoint> fixes() =>
      Geolocator.getPositionStream(
        locationSettings: AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.fitness,
          distanceFilter: 0,
          pauseLocationUpdatesAutomatically: false,
          allowBackgroundLocationUpdates: true,
          showBackgroundLocationIndicator: true,
        ),
      ).map(
        (p) => GpsPoint(
          lat: p.latitude,
          lng: p.longitude,
          time: p.timestamp.toUtc(),
          altitudeM: p.altitudeAccuracy > 0 && p.altitudeAccuracy < 30
              ? p.altitude
              : null,
          accuracyM: p.accuracy,
        ),
      );

  @override
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }
}

/// GPS on iPhone, nothing anywhere else.
LocationSource createLocationSource() =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
    ? const DeviceLocationSource()
    : const UnavailableLocationSource();
