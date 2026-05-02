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

  factory SavedTrip.fromJson(Map<String, dynamic> json) => SavedTrip(
    provider: TripProvider.fromJson(json['provider']),
    tripId: json['tripId'],
    title: json['title'],
    placeCount: json['placeCount'],
    startDate: json['startDate'],
    endDate: json['endDate'],
    firstImageKey: json['firstImageKey'],
    addedAt: json['addedAt'],
    lastAccessedAt: json['lastAccessedAt'],
  );
}
