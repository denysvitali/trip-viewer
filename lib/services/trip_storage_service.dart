import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_viewer/models/saved_trip.dart';
import 'package:trip_viewer/models/trip_plan.dart';
import 'package:trip_viewer/services/trip_cache_service.dart';

class TripStorageService {
  static const String _savedTripsKey = 'saved_trips';
  static const String _legacyTripIdKey = 'trip_id';
  static const String _legacyTripIdKey2 = 'tripId';

  static Future<List<SavedTrip>> getSavedTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_savedTripsKey);
    if (json == null) return [];
    final dynamic decoded;
    try {
      decoded = jsonDecode(json);
    } catch (_) {
      return [];
    }
    if (decoded is! List) return [];
    final trips = decoded
        .whereType<Map>()
        .map((e) => SavedTrip.fromJson(Map<String, dynamic>.from(e)))
        .where((trip) => trip.tripId.isNotEmpty)
        .toList();
    trips.sort((a, b) => b.lastAccessedAt.compareTo(a.lastAccessedAt));
    return trips;
  }

  static Future<SavedTrip> addTrip(
    String tripId, {
    TripProvider provider = TripProvider.wanderlog,
  }) async {
    final trips = await getSavedTrips();
    final existing = trips
        .where((t) => t.provider == provider && t.tripId == tripId)
        .firstOrNull;
    if (existing != null) {
      existing.lastAccessedAt = DateTime.now().millisecondsSinceEpoch;
      await _saveTrips(trips);
      return existing;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final trip = SavedTrip(
      provider: provider,
      tripId: tripId,
      addedAt: now,
      lastAccessedAt: now,
    );
    trips.add(trip);
    await _saveTrips(trips);
    return trip;
  }

  static Future<void> removeTrip(TripProvider provider, String tripId) async {
    final trips = await getSavedTrips();
    trips.removeWhere((t) => t.provider == provider && t.tripId == tripId);
    await _saveTrips(trips);
    await TripCacheService.deleteCachedTrip(provider, tripId);
  }

  static Future<void> updateTripMetadata(
    TripProvider provider,
    String tripId,
    TripPlanResponse data,
  ) async {
    final trips = await getSavedTrips();
    final trip = trips
        .where((t) => t.provider == provider && t.tripId == tripId)
        .firstOrNull;
    if (trip == null) return;

    trip.title = data.tripPlan.title;
    trip.lastAccessedAt = DateTime.now().millisecondsSinceEpoch;

    final sections =
        data.tripPlan.itinerary.sections.where((s) => s.date != null).toList();
    if (sections.isNotEmpty) {
      final dates = sections.map((s) => s.date!).toList()..sort();
      trip.startDate = dates.first;
      trip.endDate = dates.last;
    }

    int placeCount = 0;
    String? firstImage;
    for (final section in data.tripPlan.itinerary.sections) {
      for (final block in section.blocks) {
        if (block is PlaceBlock) {
          placeCount++;
          if (firstImage == null) {
            if (block.imageKeys.isNotEmpty) {
              firstImage = block.imageKeys.first;
            }
          }
        }
      }
    }
    trip.placeCount = placeCount;

    if (firstImage == null) {
      for (final pm in data.resources.placeMetadata) {
        if (pm.imageKeys.isNotEmpty) {
          firstImage = pm.imageKeys.first;
          break;
        }
      }
    }
    trip.firstImageKey = firstImage;

    await _saveTrips(trips);
  }

  static Future<void> updateLastAccessed(
    TripProvider provider,
    String tripId,
  ) async {
    final trips = await getSavedTrips();
    final trip = trips
        .where((t) => t.provider == provider && t.tripId == tripId)
        .firstOrNull;
    if (trip == null) return;
    trip.lastAccessedAt = DateTime.now().millisecondsSinceEpoch;
    await _saveTrips(trips);
  }

  /// Migrate from legacy single-trip storage to multi-trip
  static Future<bool> migrateLegacyTripId() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyId =
        prefs.getString(_legacyTripIdKey) ?? prefs.getString(_legacyTripIdKey2);
    if (legacyId == null || legacyId.isEmpty) return false;

    await addTrip(legacyId, provider: TripProvider.wanderlog);
    await prefs.remove(_legacyTripIdKey);
    await prefs.remove(_legacyTripIdKey2);
    return true;
  }

  static Future<void> _saveTrips(List<SavedTrip> trips) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(trips.map((t) => t.toJson()).toList());
    await prefs.setString(_savedTripsKey, json);
  }
}
