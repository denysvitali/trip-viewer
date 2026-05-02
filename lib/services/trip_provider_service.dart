import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
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
  static const _proxyUrl = 'https://whateverorigin.org/get?url=';

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
    final requestUrl = kIsWeb
        ? Uri.parse('$_proxyUrl${Uri.encodeComponent(url.toString())}')
        : url;
    final response = await http.get(requestUrl);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Trip provider returned ${response.statusCode}');
    }

    final decodedBody = jsonDecode(response.body);
    if (!kIsWeb) {
      return Map<String, dynamic>.from(decodedBody as Map<String, dynamic>);
    }

    final responseBody =
        decodedBody is Map<String, dynamic> && decodedBody['contents'] is String
            ? decodedBody['contents'] as String
            : response.body;

    return Map<String, dynamic>.from(jsonDecode(responseBody) as Map);
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
