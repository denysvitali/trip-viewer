import 'package:wanderlog_alt/pages/trip.dart';

class TripPlanResponse {
  final TripPlan tripPlan;

  const TripPlanResponse({required this.tripPlan});

  factory TripPlanResponse.fromJson(Map<String, dynamic> json) {
    return TripPlanResponse(tripPlan: TripPlan.fromJson(json['tripPlan']));
  }
}

class TripPlan {
  final String title;
  final int viewCount;
  final Itinerary itinerary;
  const TripPlan({
    required this.title,
    this.viewCount = 0,
    required this.itinerary,
  });
  factory TripPlan.fromJson(Map<String, dynamic> json) {
    return TripPlan(
      title: json['title'],
      viewCount: json['viewCount'],
      itinerary: Itinerary.fromJson(json['itinerary']),
    );
  }
}

class Itinerary {
  final List<Section> sections;
  const Itinerary({required this.sections});
  factory Itinerary.fromJson(Map<String, dynamic> json) {
    return Itinerary(sections: getSections(json['sections']));
  }
}

List<Section> getSections(List<dynamic> json) {
  return json.map((section) => Section.fromJson(section)).toList();
}

class Section {
  final String heading;
  final List<Block> blocks;
  final String? date;

  const Section(
      {required this.heading, required this.date, required this.blocks});
  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      date: json['date'],
      heading: json['heading'],
      blocks: getBlocks(json['blocks']),
    );
  }
}

List<Block> getBlocks(List<dynamic> json) {
  return json.map((block) => getBlock(block)).toList();
}

Block getBlock(Map<String, dynamic> json) {
  switch (json['type']) {
    case 'place':
      return PlaceBlock.fromJson(json);
  }
  return Block.fromJson(json);
}

class Block {
  final String type;
  final List<String> imageKeys;
  Block({required this.type, List<String>? imageKeys})
      : imageKeys = imageKeys ?? List.empty(growable: true);

  factory Block.fromJson(Map<String, dynamic> json) {
    return Block(
      type: json['type'],
    );
  }
}

class PlaceBlock extends Block {
  final String? name;
  final String? formattedAddress;
  final double? latitude;
  final double? longitude;
  final String? website;
  final List<String>? types;
  final String? url;
  final Hotel? hotel;

  PlaceBlock({
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    required this.website,
    required this.types,
    required this.url,
    this.hotel,
    super.imageKeys,
  }) : super(type: 'place');

  factory PlaceBlock.fromJson(Map<String, dynamic> json) {
    return PlaceBlock(
      name: json['place']['name'],
      formattedAddress: json['place']['formattedAddress'],
      latitude: json['place']['geometry']['location']['lat'],
      longitude: json['place']['geometry']['location']['lng'],
      website: json['place']['website'],
      types: getListStrings(json['place']['types']),
      url: json['place']['url'],
      hotel: json['hotel'] != null ? Hotel.fromJson(json['hotel']) : null,
      imageKeys: getListStrings(json['imageKeys']),
    );
  }
}

class Hotel {
  final String? checkIn;
  final String? checkOut;
  final String? confirmationNumber;

  Hotel({
    required this.checkIn,
    required this.checkOut,
    required this.confirmationNumber,
  });

  factory Hotel.fromJson(Map<String, dynamic> json) {
    return Hotel(
      checkIn: json['checkIn'],
      checkOut: json['checkOut'],
      confirmationNumber: json['confirmationNumber'],
    );
  }
}
