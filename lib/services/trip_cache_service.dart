import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TripCacheService {
  static const String _tripDataKey = 'trip_data_';
  static const String _lastFetchKey = 'last_fetch_';

  static Future<void> cacheTrip(
      String tripId, Map<String, dynamic> tripData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_tripDataKey$tripId', jsonEncode(tripData));
    await prefs.setInt(
        '$_lastFetchKey$tripId', DateTime.now().millisecondsSinceEpoch);
  }

  static Future<Map<String, dynamic>?> getCachedTrip(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('$_tripDataKey$tripId');
    return cachedData != null ? jsonDecode(cachedData) : null;
  }

  static Future<DateTime?> getLastFetchTime(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('$_lastFetchKey$tripId');
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }
}
