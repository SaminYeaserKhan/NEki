import 'dart:convert';
import 'dart:math';

/// Represents a geographic location for prayer calculation.
class PrayerLocation {
  final String cityName;
  final String countryName;
  final double latitude;
  final double longitude;
  final bool isAutoGps;
  final DateTime? lastUpdated;

  const PrayerLocation({
    required this.cityName,
    required this.countryName,
    required this.latitude,
    required this.longitude,
    this.isAutoGps = false,
    this.lastUpdated,
  });

  /// Default fallback: Dhaka, Bangladesh.
  static const PrayerLocation defaultLocation = PrayerLocation(
    cityName: 'Dhaka',
    countryName: 'Bangladesh',
    latitude: 23.8103,
    longitude: 90.4125,
    isAutoGps: false,
  );

  String get displayName =>
      countryName.isNotEmpty ? '$cityName, $countryName' : cityName;

  Map<String, dynamic> toMap() {
    return {
      'cityName': cityName,
      'countryName': countryName,
      'latitude': latitude,
      'longitude': longitude,
      'isAutoGps': isAutoGps,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  factory PrayerLocation.fromMap(Map<String, dynamic> map) {
    return PrayerLocation(
      cityName: map['cityName'] as String? ?? 'Dhaka',
      countryName: map['countryName'] as String? ?? 'Bangladesh',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 23.8103,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 90.4125,
      isAutoGps: map['isAutoGps'] as bool? ?? false,
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.tryParse(map['lastUpdated'] as String)
          : null,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory PrayerLocation.fromJson(String source) =>
      PrayerLocation.fromMap(jsonDecode(source) as Map<String, dynamic>);

  PrayerLocation copyWith({
    String? cityName,
    String? countryName,
    double? latitude,
    double? longitude,
    bool? isAutoGps,
    DateTime? lastUpdated,
  }) {
    return PrayerLocation(
      cityName: cityName ?? this.cityName,
      countryName: countryName ?? this.countryName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isAutoGps: isAutoGps ?? this.isAutoGps,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerLocation &&
          runtimeType == other.runtimeType &&
          cityName == other.cityName &&
          countryName == other.countryName &&
          (latitude - other.latitude).abs() < 0.0001 &&
          (longitude - other.longitude).abs() < 0.0001 &&
          isAutoGps == other.isAutoGps;

  @override
  int get hashCode =>
      cityName.hashCode ^
      countryName.hashCode ^
      latitude.hashCode ^
      longitude.hashCode ^
      isAutoGps.hashCode;
}

/// Offline database of major Islamic and global cities for instant offline calculation.
const List<PrayerLocation> kPredefinedCities = [
  // ── Bangladesh Divisions & Districts ──
  PrayerLocation(
      cityName: 'Dhaka',
      countryName: 'Bangladesh',
      latitude: 23.8103,
      longitude: 90.4125),
  PrayerLocation(
      cityName: 'Chittagong',
      countryName: 'Bangladesh',
      latitude: 22.3569,
      longitude: 91.7832),
  PrayerLocation(
      cityName: 'Sylhet',
      countryName: 'Bangladesh',
      latitude: 24.8949,
      longitude: 91.8687),
  PrayerLocation(
      cityName: 'Rajshahi',
      countryName: 'Bangladesh',
      latitude: 24.3745,
      longitude: 88.6042),
  PrayerLocation(
      cityName: 'Khulna',
      countryName: 'Bangladesh',
      latitude: 22.8456,
      longitude: 89.5403),
  PrayerLocation(
      cityName: 'Barisal',
      countryName: 'Bangladesh',
      latitude: 22.7010,
      longitude: 90.3535),
  PrayerLocation(
      cityName: 'Rangpur',
      countryName: 'Bangladesh',
      latitude: 25.7439,
      longitude: 89.2752),
  PrayerLocation(
      cityName: 'Mymensingh',
      countryName: 'Bangladesh',
      latitude: 24.7471,
      longitude: 90.4203),
  PrayerLocation(
      cityName: 'Comilla',
      countryName: 'Bangladesh',
      latitude: 23.4682,
      longitude: 91.1788),
  PrayerLocation(
      cityName: "Cox's Bazar",
      countryName: 'Bangladesh',
      latitude: 21.4272,
      longitude: 92.0058),

  // ── Islamic Holy & Historic Cities ──
  PrayerLocation(
      cityName: 'Makkah',
      countryName: 'Saudi Arabia',
      latitude: 21.4225,
      longitude: 39.8262),
  PrayerLocation(
      cityName: 'Madinah',
      countryName: 'Saudi Arabia',
      latitude: 24.5247,
      longitude: 39.5692),
  PrayerLocation(
      cityName: 'Jerusalem',
      countryName: 'Palestine',
      latitude: 31.7683,
      longitude: 35.2137),
  PrayerLocation(
      cityName: 'Cairo',
      countryName: 'Egypt',
      latitude: 30.0444,
      longitude: 31.2357),
  PrayerLocation(
      cityName: 'Istanbul',
      countryName: 'Turkey',
      latitude: 41.0082,
      longitude: 28.9784),

  // ── Middle East & South Asia ──
  PrayerLocation(
      cityName: 'Dubai',
      countryName: 'UAE',
      latitude: 25.2048,
      longitude: 55.2708),
  PrayerLocation(
      cityName: 'Doha',
      countryName: 'Qatar',
      latitude: 25.2854,
      longitude: 51.5310),
  PrayerLocation(
      cityName: 'Riyadh',
      countryName: 'Saudi Arabia',
      latitude: 24.7136,
      longitude: 46.6753),
  PrayerLocation(
      cityName: 'Karachi',
      countryName: 'Pakistan',
      latitude: 24.8607,
      longitude: 67.0011),
  PrayerLocation(
      cityName: 'Lahore',
      countryName: 'Pakistan',
      latitude: 31.5204,
      longitude: 74.3587),
  PrayerLocation(
      cityName: 'Islamabad',
      countryName: 'Pakistan',
      latitude: 33.6844,
      longitude: 73.0479),
  PrayerLocation(
      cityName: 'Kuala Lumpur',
      countryName: 'Malaysia',
      latitude: 3.1390,
      longitude: 101.6869),
  PrayerLocation(
      cityName: 'Jakarta',
      countryName: 'Indonesia',
      latitude: -6.2088,
      longitude: 106.8456),
  PrayerLocation(
      cityName: 'Singapore',
      countryName: 'Singapore',
      latitude: 1.3521,
      longitude: 103.8198),

  // ── Global Major Cities ──
  PrayerLocation(
      cityName: 'London',
      countryName: 'United Kingdom',
      latitude: 51.5074,
      longitude: -0.1278),
  PrayerLocation(
      cityName: 'New York',
      countryName: 'United States',
      latitude: 40.7128,
      longitude: -74.0060),
  PrayerLocation(
      cityName: 'Toronto',
      countryName: 'Canada',
      latitude: 43.6532,
      longitude: -79.3832),
  PrayerLocation(
      cityName: 'Sydney',
      countryName: 'Australia',
      latitude: -33.8688,
      longitude: 151.2093),
  PrayerLocation(
      cityName: 'Tokyo',
      countryName: 'Japan',
      latitude: 35.6762,
      longitude: 139.6503),
  PrayerLocation(
      cityName: 'Berlin',
      countryName: 'Germany',
      latitude: 52.5200,
      longitude: 13.4050),
  PrayerLocation(
      cityName: 'Paris',
      countryName: 'France',
      latitude: 48.8566,
      longitude: 2.3522),
];

/// Finds the nearest city in our offline database using the Haversine distance formula.
PrayerLocation findNearestOfflineCity(double latitude, double longitude) {
  PrayerLocation nearest = kPredefinedCities.first;
  double minDistance = double.infinity;

  for (final city in kPredefinedCities) {
    final dist = _haversineDistance(latitude, longitude, city.latitude, city.longitude);
    if (dist < minDistance) {
      minDistance = dist;
      nearest = city;
    }
  }

  // If within 50km, adopt the city name, otherwise return with coordinates and nearest label
  if (minDistance <= 50) {
    return nearest.copyWith(
      latitude: latitude,
      longitude: longitude,
      isAutoGps: true,
    );
  } else {
    return PrayerLocation(
      cityName: '${nearest.cityName} Region',
      countryName: nearest.countryName,
      latitude: latitude,
      longitude: longitude,
      isAutoGps: true,
    );
  }
}

double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;
  final dLat = _degreesToRadians(lat2 - lat1);
  final dLon = _degreesToRadians(lon2 - lon1);

  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_degreesToRadians(lat1)) *
          cos(_degreesToRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}

double _degreesToRadians(double degrees) => degrees * pi / 180.0;
