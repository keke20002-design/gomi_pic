import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _manualMunicipalityKey = 'gomi_pic_manual_municipality';
  static const _nonJapanNoticeDismissedKey = 'gomi_pic_non_japan_dismissed';

  const SettingsService();

  Future<String?> getManualMunicipality() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_manualMunicipalityKey);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<void> setManualMunicipality(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(_manualMunicipalityKey);
    } else {
      await prefs.setString(_manualMunicipalityKey, value.trim());
    }
  }

  Future<bool> isNonJapanNoticeDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_nonJapanNoticeDismissedKey) ?? false;
  }

  Future<void> dismissNonJapanNotice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_nonJapanNoticeDismissedKey, true);
  }
}
