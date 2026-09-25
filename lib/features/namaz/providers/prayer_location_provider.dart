import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prayer_location.dart';

class PrayerLocationState {
  final PrayerLocation location;
  final bool isLoadingGps;
  final String? errorMessage;
  final LocationPermission? permissionStatus;

  const PrayerLocationState({
    required this.location,
    this.isLoadingGps = false,
    this.errorMessage,
    this.permissionStatus,
  });

  PrayerLocationState copyWith({
    PrayerLocation? location,
    bool? isLoadingGps,
    String? errorMessage,
    LocationPermission? permissionStatus,
    bool clearError = false,
  }) {
    return PrayerLocationState(
      location: location ?? this.location,
      isLoadingGps: isLoadingGps ?? this.isLoadingGps,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      permissionStatus: permissionStatus ?? this.permissionStatus,
    );
  }
}

class PrayerLocationNotifier extends Notifier<PrayerLocationState> {
  static const _prefsKey = 'neki_prayer_location_v1';

  @override
  PrayerLocationState build() {
    _loadSavedLocation();
    return const PrayerLocationState(
      location: PrayerLocation.defaultLocation,
    );
  }

  Future<void> _loadSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_prefsKey);
      if (savedJson != null) {
        final loc = PrayerLocation.fromJson(savedJson);
        state = state.copyWith(location: loc);
      } else {
        // Try getting GPS silently on initial start if permitted
        _initGpsSilently();
      }
    } catch (e) {
      debugPrint('Error loading saved location: $e');
    }
  }

  Future<void> _initGpsSilently() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        await refreshGpsLocation();
      }
    } catch (_) {
      // Keep default location
    }
  }

  /// Request GPS location and resolve city/country with reverse geocoding.
  Future<bool> refreshGpsLocation() async {
    state = state.copyWith(isLoadingGps: true, clearError: true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          isLoadingGps: false,
          errorMessage: 'Location services are disabled on your device.',
        );
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(
            isLoadingGps: false,
            errorMessage: 'Location permission was denied.',
            permissionStatus: permission,
          );
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          isLoadingGps: false,
          errorMessage:
              'Location permissions are permanently denied. Please select a city manually or enable it in Settings.',
          permissionStatus: permission,
        );
        return false;
      }

      // Fetch position with standard timeout
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      String cityName = 'Current Location';
      String countryName = '';

      // Attempt reverse geocoding
      try {
        final placemarks = await Geocoding().placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          cityName = p.locality?.isNotEmpty == true
              ? p.locality!
              : (p.subAdministrativeArea?.isNotEmpty == true
                  ? p.subAdministrativeArea!
                  : p.administrativeArea ?? 'Unknown City');
          countryName = p.country ?? '';
        }
      } catch (geocodeErr) {
        debugPrint('Geocoding error, falling back to nearest offline city: $geocodeErr');
        final nearest = findNearestOfflineCity(position.latitude, position.longitude);
        cityName = nearest.cityName;
        countryName = nearest.countryName;
      }

      final newLocation = PrayerLocation(
        cityName: cityName,
        countryName: countryName,
        latitude: position.latitude,
        longitude: position.longitude,
        isAutoGps: true,
        lastUpdated: DateTime.now(),
      );

      state = state.copyWith(
        location: newLocation,
        isLoadingGps: false,
        clearError: true,
      );

      // Persist
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, newLocation.toJson());
      return true;
    } catch (e) {
      debugPrint('Error getting GPS location: $e');
      state = state.copyWith(
        isLoadingGps: false,
        errorMessage: 'Unable to detect GPS. Using ${state.location.cityName}.',
      );
      return false;
    }
  }

  /// Sets a manually chosen location (e.g. from predefined list or search).
  Future<void> selectLocation(PrayerLocation location) async {
    final updated = location.copyWith(
      isAutoGps: false,
      lastUpdated: DateTime.now(),
    );
    state = state.copyWith(
      location: updated,
      clearError: true,
      isLoadingGps: false,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, updated.toJson());
  }

  /// Search offline cities or online geocode
  Future<List<PrayerLocation>> searchCities(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return kPredefinedCities;

    // Filter offline cities first
    final matches = kPredefinedCities.where((c) {
      return c.cityName.toLowerCase().contains(q) ||
          c.countryName.toLowerCase().contains(q);
    }).toList();

    // If query has length >= 3 and not enough matches, try online geocoding
    if (matches.length < 3 && q.length >= 3) {
      try {
        final locations = await Geocoding().locationFromAddress(query);
        for (final loc in locations.take(3)) {
          matches.add(
            PrayerLocation(
              cityName: query,
              countryName: '',
              latitude: loc.latitude,
              longitude: loc.longitude,
              isAutoGps: false,
            ),
          );
        }
      } catch (_) {
        // Ignore online geocode failures
      }
    }

    return matches;
  }
}

final prayerLocationProvider =
    NotifierProvider<PrayerLocationNotifier, PrayerLocationState>(
  PrayerLocationNotifier.new,
);
