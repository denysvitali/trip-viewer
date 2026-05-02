import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_viewer/models/saved_trip.dart';

class TripCacheService {
  static const String _tripDataKey = 'trip_data_';
  static const String _lastFetchKey = 'last_fetch_';
  static const Duration ttl = Duration(days: 7);

  static String cacheKey(TripProvider provider, String tripId) {
    return '${provider.name}:$tripId';
  }

  static Future<void> cacheTrip(
    TripProvider provider,
    String tripId,
    Map<String, dynamic> tripData,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = cacheKey(provider, tripId);
    await prefs.setString('$_tripDataKey$key', jsonEncode(tripData));
    await prefs.setInt(
      '$_lastFetchKey$key',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<Map<String, dynamic>?> getCachedTrip(
    TripProvider provider,
    String tripId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = cacheKey(provider, tripId);
    final cachedData =
        prefs.getString('$_tripDataKey$key') ??
        (provider == TripProvider.wanderlog
            ? prefs.getString('$_tripDataKey$tripId')
            : null);
    if (cachedData == null) return null;
    return Map<String, dynamic>.from(jsonDecode(cachedData));
  }

  static Future<DateTime?> getLastFetchTime(
    TripProvider provider,
    String tripId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = cacheKey(provider, tripId);
    final timestamp =
        prefs.getInt('$_lastFetchKey$key') ??
        (provider == TripProvider.wanderlog
            ? prefs.getInt('$_lastFetchKey$tripId')
            : null);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  static Future<bool> shouldRefresh(
    TripProvider provider,
    String tripId,
  ) async {
    final lastFetch = await getLastFetchTime(provider, tripId);
    if (lastFetch == null) return true;
    return DateTime.now().difference(lastFetch) >= ttl;
  }

  static Future<void> deleteCachedTrip(
    TripProvider provider,
    String tripId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = cacheKey(provider, tripId);
    await prefs.remove('$_tripDataKey$key');
    await prefs.remove('$_lastFetchKey$key');
    if (provider == TripProvider.wanderlog) {
      await prefs.remove('$_tripDataKey$tripId');
      await prefs.remove('$_lastFetchKey$tripId');
    }
  }
}
