enum TripProvider {
  wanderlog;

  String get displayName {
    switch (this) {
      case TripProvider.wanderlog:
        return 'Wanderlog';
    }
  }

  static TripProvider fromJson(String? value) {
    return TripProvider.values.firstWhere(
      (provider) => provider.name == value,
      orElse: () => TripProvider.wanderlog,
    );
  }
}

class SavedTrip {
  final TripProvider provider;
  final String tripId;
  String? title;
  int? placeCount;
  String? startDate;
  String? endDate;
  String? firstImageKey;
  final int addedAt;
  int lastAccessedAt;

  SavedTrip({
    this.provider = TripProvider.wanderlog,
    required this.tripId,
    this.title,
    this.placeCount,
    this.startDate,
    this.endDate,
    this.firstImageKey,
    required this.addedAt,
    required this.lastAccessedAt,
  });

  String get cacheKey => '${provider.name}:$tripId';

  Map<String, dynamic> toJson() => {
        'provider': provider.name,
        'tripId': tripId,
        'title': title,
        'placeCount': placeCount,
        'startDate': startDate,
        'endDate': endDate,
        'firstImageKey': firstImageKey,
        'addedAt': addedAt,
        'lastAccessedAt': lastAccessedAt,
      };

  factory SavedTrip.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final provider = json['provider'];
    final tripId = json['tripId'];
    final addedAt = _optionalInt(json['addedAt']);

    return SavedTrip(
      provider: TripProvider.fromJson(provider is String ? provider : null),
      tripId: tripId is String ? tripId : '',
      title: _optionalString(json['title']),
      placeCount: _optionalInt(json['placeCount']),
      startDate: _optionalString(json['startDate']),
      endDate: _optionalString(json['endDate']),
      firstImageKey: _optionalString(json['firstImageKey']),
      addedAt: addedAt ?? now,
      lastAccessedAt: _optionalInt(json['lastAccessedAt']) ?? addedAt ?? now,
    );
  }
}

String? _optionalString(dynamic value) => value is String ? value : null;

int? _optionalInt(dynamic value) => value is num ? value.toInt() : null;
