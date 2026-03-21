class SavedTrip {
  final String tripId;
  String? title;
  int? placeCount;
  String? startDate;
  String? endDate;
  String? firstImageKey;
  final int addedAt;
  int lastAccessedAt;

  SavedTrip({
    required this.tripId,
    this.title,
    this.placeCount,
    this.startDate,
    this.endDate,
    this.firstImageKey,
    required this.addedAt,
    required this.lastAccessedAt,
  });

  Map<String, dynamic> toJson() => {
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
