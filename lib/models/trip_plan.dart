import 'package:json_annotation/json_annotation.dart';

part 'trip_plan.g.dart';

class TripPlanResponse {
  final TripPlan tripPlan;

  const TripPlanResponse({required this.tripPlan});

  factory TripPlanResponse.fromJson(Map<String, dynamic> json) {
    return TripPlanResponse(
      tripPlan: json['tripPlan'] != null
          ? TripPlan.fromJson(json['tripPlan'])
          : throw ArgumentError('tripPlan is null'),
    );
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
    case 'flight':
      return FlightBlock.fromJson(json);
    case 'note':
      return NoteBlock.fromJson(json);
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
      imageKeys: json['imageKeys'] != null
          ? List<String>.from(json['imageKeys'])
          : List.empty(growable: true),
    );
  }
}

@JsonSerializable()
class PlaceBlock extends Block {
  final GooglePlace place;
  final Hotel? hotel;
  PlaceBlock({
    required this.place,
    required this.hotel,
    super.imageKeys,
  }) : super(type: 'place');

  factory PlaceBlock.fromJson(Map<String, dynamic> json) =>
      _$PlaceBlockFromJson(json);
}

@JsonSerializable()
class TextOps {
  final String insert;
  final String? attributes;
  TextOps({required this.insert, this.attributes});
  factory TextOps.fromJson(Map<String, dynamic> json) =>
      _$TextOpsFromJson(json);
}

@JsonSerializable()
class TextContainer {
  final List<TextOps> ops;
  TextContainer({required this.ops});
  factory TextContainer.fromJson(Map<String, dynamic> json) =>
      _$TextContainerFromJson(json);
}

@JsonSerializable()
class NoteBlock extends Block {
  final TextContainer text;
  NoteBlock({required this.text, super.imageKeys}) : super(type: 'note');
  factory NoteBlock.fromJson(Map<String, dynamic> json) =>
      _$NoteBlockFromJson(json);
}

@JsonSerializable()
class Airline {
  final String iata;
  final String icao;
  final String name;
  final String localizedName;

  Airline({
    required this.iata,
    required this.icao,
    required this.name,
    required this.localizedName,
  });

  factory Airline.fromJson(Map<String, dynamic> json) =>
      _$AirlineFromJson(json);
}

@JsonSerializable()
class Photo {
  final int height;
  final int width;

  @JsonKey(name: 'photo_reference')
  final String photoReference;

  Photo(
      {required this.height,
      required this.width,
      required this.photoReference});

  factory Photo.fromJson(Map<String, dynamic> json) => _$PhotoFromJson(json);
}

@JsonSerializable()
class GooglePlace {
  @JsonKey(name: 'formatted_address')
  final String formattedAddress;
  final String name;
  final List<Photo>? photos;
  final String? url;

  GooglePlace({
    required this.formattedAddress,
    required this.name,
    required this.photos,
    required this.url,
  });

  factory GooglePlace.fromJson(Map<String, dynamic> json) =>
      _$GooglePlaceFromJson(json);
}

@JsonSerializable()
class Airport {
  final String iata;
  final String name;
  final String cityName;
  final GooglePlace googlePlace;

  Airport(
      {required this.iata,
      required this.name,
      required this.cityName,
      required this.googlePlace});

  factory Airport.fromJson(Map<String, dynamic> json) =>
      _$AirportFromJson(json);
}

@JsonSerializable()
class DepartArrive {
  final String date;
  final String time;
  final Airport airport;

  DepartArrive({required this.date, required this.time, required this.airport});

  factory DepartArrive.fromJson(Map<String, dynamic> json) =>
      _$DepartArriveFromJson(json);
}

@JsonSerializable()
class FlightInfo {
  final Airline airline;
  final int number;

  FlightInfo({
    required this.airline,
    required this.number,
  });

  factory FlightInfo.fromJson(Map<String, dynamic> json) =>
      _$FlightInfoFromJson(json);
}

@JsonSerializable()
class FlightBlock extends Block {
  final FlightInfo flightInfo;
  final DepartArrive depart;
  final DepartArrive arrive;
  FlightBlock({
    required this.flightInfo,
    required this.depart,
    required this.arrive,
    super.imageKeys,
  }) : super(type: 'flight');

  factory FlightBlock.fromJson(Map<String, dynamic> json) =>
      _$FlightBlockFromJson(json);
}

@JsonSerializable()
class Hotel {
  final String? checkIn;
  final String? checkOut;
  final String? confirmationNumber;

  Hotel({
    required this.checkIn,
    required this.checkOut,
    required this.confirmationNumber,
  });

  factory Hotel.fromJson(Map<String, dynamic> json) => _$HotelFromJson(json);
}
