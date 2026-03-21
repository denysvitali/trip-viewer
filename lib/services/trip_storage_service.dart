import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderlog_alt/models/saved_trip.dart';
import 'package:wanderlog_alt/models/trip_plan.dart';
import 'package:wanderlog_alt/services/trip_cache_service.dart';

class TripStorageService {
  static const String _savedTripsKey = 'saved_trips';
  static const String _legacyTripIdKey = 'trip_id';
  static const String _legacyTripIdKey2 = 'tripId';

  static Future<List<SavedTrip>> getSavedTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_savedTripsKey);
    if (json == null) return [];
    final List<dynamic> decoded = jsonDecode(json);
    final trips = decoded.map((e) => SavedTrip.fromJson(e)).toList();
    trips.sort((a, b) => b.lastAccessedAt.compareTo(a.lastAccessedAt));
    return trips;
  }

  static Future<SavedTrip> addTrip(String tripId) async {
    final trips = await getSavedTrips();
    final existing = trips.where((t) => t.tripId == tripId).firstOrNull;
    if (existing != null) {
      existing.lastAccessedAt = DateTime.now().millisecondsSinceEpoch;
      await _saveTrips(trips);
      return existing;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final trip = SavedTrip(
      tripId: tripId,
      addedAt: now,
      lastAccessedAt: now,
    );
    trips.add(trip);
    await _saveTrips(trips);
    return trip;
  }

  static Future<void> removeTrip(String tripId) async {
    final trips = await getSavedTrips();
    trips.removeWhere((t) => t.tripId == tripId);
    await _saveTrips(trips);
    await TripCacheService.deleteCachedTrip(tripId);
  }

  static Future<void> updateTripMetadata(
      String tripId, TripPlanResponse data) async {
    final trips = await getSavedTrips();
    final trip = trips.where((t) => t.tripId == tripId).firstOrNull;
    if (trip == null) return;

    trip.title = data.tripPlan.title;
    trip.lastAccessedAt = DateTime.now().millisecondsSinceEpoch;

    final sections = data.tripPlan.itinerary.sections
        .where((s) => s.date != null)
        .toList();
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

  static Future<void> updateLastAccessed(String tripId) async {
    final trips = await getSavedTrips();
    final trip = trips.where((t) => t.tripId == tripId).firstOrNull;
    if (trip == null) return;
    trip.lastAccessedAt = DateTime.now().millisecondsSinceEpoch;
    await _saveTrips(trips);
  }

  /// Migrate from legacy single-trip storage to multi-trip
  static Future<bool> migrateLegacyTripId() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyId = prefs.getString(_legacyTripIdKey) ??
        prefs.getString(_legacyTripIdKey2);
    if (legacyId == null || legacyId.isEmpty) return false;

    await addTrip(legacyId);
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
