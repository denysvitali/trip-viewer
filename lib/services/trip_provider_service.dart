import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:trip_viewer/models/saved_trip.dart';

class TripImportReference {
  final TripProvider provider;
  final String tripId;

  const TripImportReference({required this.provider, required this.tripId});
}

abstract class TripProviderClient {
  TripProvider get provider;
  String get displayName;
  String parseTripId(String input);
  Future<Map<String, dynamic>> fetchTrip(String tripId);
}

class WanderlogTripProviderClient implements TripProviderClient {
  static const _apiUrl = 'https://wanderlog.com/api/tripPlans/';

  @override
  TripProvider get provider => TripProvider.wanderlog;

  @override
  String get displayName => provider.displayName;

  @override
  String parseTripId(String input) {
    final trimmed = input.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.host.contains('wanderlog.com')) {
      final segments = uri.pathSegments;
      if (segments.length >= 2) {
        return segments[1];
      }
    }
    return trimmed;
  }

  @override
  Future<Map<String, dynamic>> fetchTrip(String tripId) async {
    final url = Uri.parse('$_apiUrl$tripId?clientSchemaVersion=2');
    final response = await http.get(url);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Trip provider returned ${response.statusCode}');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body));
  }
}

class TripProviderService {
  static final List<TripProviderClient> providers = [
    WanderlogTripProviderClient(),
  ];

  static TripProviderClient clientFor(TripProvider provider) {
    return providers.firstWhere((client) => client.provider == provider);
  }

  static TripImportReference parseImport({
    required TripProvider provider,
    required String input,
  }) {
    final client = clientFor(provider);
    return TripImportReference(
      provider: provider,
      tripId: client.parseTripId(input),
    );
  }

  static Future<Map<String, dynamic>> fetchTrip({
    required TripProvider provider,
    required String tripId,
  }) {
    return clientFor(provider).fetchTrip(tripId);
  }
}
