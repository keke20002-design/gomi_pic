import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'settings_service.dart';

class LocationResult {
  final String municipality;
  final double latitude;
  final double longitude;
  final bool isManual;

  const LocationResult({
    required this.municipality,
    required this.latitude,
    required this.longitude,
    this.isManual = false,
  });
}

class LocationService {
  const LocationService();

  Future<LocationResult> getCurrentMunicipality() async {
    final manual = await const SettingsService().getManualMunicipality();
    if (manual != null) {
      return LocationResult(
        municipality: manual,
        latitude: 0,
        longitude: 0,
        isManual: true,
      );
    }

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const LocationException('位置情報サービスが無効です');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException('位置情報の権限が拒否されました');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException('位置情報の権限が永久に拒否されています');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 10),
      ),
    );

    await setLocaleIdentifier('ja_JP');
    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isEmpty) {
      throw const LocationException('住所情報を取得できませんでした');
    }
    final placemark = placemarks.first;
    final country = placemark.isoCountryCode?.trim().toUpperCase() ?? '';
    if (country.isNotEmpty && country != 'JP') {
      throw LocationException(
        'ゴミチェックは日本の自治体専用です。現在地が日本ではありません（検出: ${placemark.country ?? country}）。',
      );
    }

    final municipality = _extractJapaneseMunicipality(placemark);
    return LocationResult(
      municipality: municipality,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  String _extractJapaneseMunicipality(Placemark p) {
    // 日本: subAdministrativeArea ≒ 市, locality ≒ 区/市/町/村
    // 東京23区の場合は locality に "渋谷区" のように入る。
    final locality = p.locality?.trim();
    final subArea = p.subAdministrativeArea?.trim();
    final admin = p.administrativeArea?.trim();

    if (locality != null && locality.isNotEmpty) {
      if (admin != null && admin.isNotEmpty && admin != locality) {
        return '$admin$locality';
      }
      return locality;
    }
    if (subArea != null && subArea.isNotEmpty) return subArea;
    if (admin != null && admin.isNotEmpty) return admin;
    return '不明';
  }
}

class LocationException implements Exception {
  final String message;
  const LocationException(this.message);
  @override
  String toString() => message;
}
