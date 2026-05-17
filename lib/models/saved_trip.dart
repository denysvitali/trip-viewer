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
    final tripId = json['tripId'] as String?;
    final addedAt = (json['addedAt'] as num?)?.toInt();

    return SavedTrip(
      provider: TripProvider.fromJson(json['provider'] as String?),
      tripId: tripId ?? '',
      title: json['title'] as String?,
      placeCount: (json['placeCount'] as num?)?.toInt(),
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      firstImageKey: json['firstImageKey'] as String?,
      addedAt: addedAt ?? now,
      lastAccessedAt:
          (json['lastAccessedAt'] as num?)?.toInt() ?? addedAt ?? now,
    );
  }
}
