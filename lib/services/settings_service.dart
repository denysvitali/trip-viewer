import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _tripIdKey = 'trip_id';

  static Future<String?> getTripId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tripIdKey);
  }

  static Future<void> setTripId(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tripIdKey, tripId);
  }
}
