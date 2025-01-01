import 'package:json_annotation/json_annotation.dart';

part 'trip_plan.g.dart';

@JsonSerializable()
class TripPlanResponse {
  final TripPlan tripPlan;
  final Resources resources;

  const TripPlanResponse({required this.tripPlan, required this.resources});
  factory TripPlanResponse.fromJson(Map<String, dynamic> json) =>
      _$TripPlanResponseFromJson(json);
}

@JsonSerializable()
class PlaceMetadata {
  final int id;
  final String name;
  final String placeId;
  final String? generatedDescription;
  final String? description;
  final double? rating;
  final int? numRatings;
  List<String> imageKeys = [];

  PlaceMetadata({
    required this.id,
    required this.name,
    required this.placeId,
    required this.generatedDescription,
    required this.description,
    required this.imageKeys,
    required this.rating,
    required this.numRatings,
  });
  factory PlaceMetadata.fromJson(Map<String, dynamic> json) =>
      _$PlaceMetadataFromJson(json);
}

@JsonSerializable()
class Resources {
  final List<PlaceMetadata> placeMetadata;

  Resources({required this.placeMetadata});
  factory Resources.fromJson(Map<String, dynamic> json) =>
      _$ResourcesFromJson(json);
}

@JsonSerializable()
class TripPlan {
  final String title;
  final int viewCount;
  final Itinerary itinerary;

  const TripPlan({
    required this.title,
    this.viewCount = 0,
    required this.itinerary,
  });
  factory TripPlan.fromJson(Map<String, dynamic> json) =>
      _$TripPlanFromJson(json);
}

@JsonSerializable()
class Itinerary {
  final List<Section> sections;
  final Budget budget;
  const Itinerary({required this.sections, required this.budget});
  factory Itinerary.fromJson(Map<String, dynamic> json) =>
      _$ItineraryFromJson(json);
}

@JsonSerializable()
class Budget {
  final List<Expense> expenses;

  Budget({required this.expenses});
  factory Budget.fromJson(Map<String, dynamic> json) =>
      _$BudgetFromJson(json);
}

List<Section> getSections(List<dynamic> json) {
  return json.map((section) => Section.fromJson(section)).toList();
}

@JsonSerializable()
class Section {
  final String heading;
  final List<Block> blocks;
  final String? date;

  const Section(
      {required this.heading, required this.date, required this.blocks});
  factory Section.fromJson(Map<String, dynamic> json) =>
      _$SectionFromJson(json);
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

@JsonSerializable()
class Block {
  final String type;
  final List<String> imageKeys;
  final Expense? price;
  final int? expenseId;

  Block({required this.type, this.imageKeys = const [], this.price, this.expenseId});

  factory Block.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'place':
        return PlaceBlock.fromJson(json);
      case 'flight':
        return FlightBlock.fromJson(json);
      case 'note':
        return NoteBlock.fromJson(json);
      case 'bus':
      case 'train':
      case 'ferry':
        return TransitBlock.fromJson(json);
    }
    return Block(type: json['type'], imageKeys: json['image_keys'] ?? [], price: json['price'] != null ? Expense.fromJson(json['price']) : null, expenseId: json['expenseId']);
  }
}

@JsonSerializable()
class PlaceBlock extends Block {
  final GooglePlace place;
  final Hotel? hotel;
  final String? startTime;
  final String? endTime;
  PlaceBlock({
    required this.place,
    required this.hotel,
    required this.startTime,
    required this.endTime,
    super.imageKeys,
    super.price,
    super.expenseId,
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
  NoteBlock({required this.text, super.imageKeys, super.price, super.expenseId}) : super(type: 'note');
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
  @JsonKey(name: 'place_id')
  final String placeId;
  final String name;
  final List<Photo>? photos;
  final String? url;

  GooglePlace({
    required this.formattedAddress,
    required this.name,
    required this.photos,
    required this.url,
    required this.placeId,
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
class DepartArrivePlace {
  final String date;
  final String? time;
  final GooglePlace place;

  DepartArrivePlace(
      {required this.date, required this.time, required this.place});

  factory DepartArrivePlace.fromJson(Map<String, dynamic> json) =>
      _$DepartArrivePlaceFromJson(json);
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
  final String? confirmationNumber;
  FlightBlock({
    required this.flightInfo,
    required this.depart,
    required this.arrive,
    required this.confirmationNumber,
    super.imageKeys,
    super.price,
    super.expenseId,
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

@JsonSerializable()
class TransitBlock extends Block {
  final DepartArrivePlace depart;
  final DepartArrivePlace arrive;
  final String? confirmationNumber;
  final String? carrier;

  TransitBlock({
    required this.depart,
    required this.arrive,
    required this.confirmationNumber,
    required this.carrier,
    required super.type,
    super.price,
    super.expenseId,
  });

  factory TransitBlock.fromJson(Map<String, dynamic> json) =>
      _$TransitBlockFromJson(json);
}

@JsonSerializable()
class Expense {
  final int id;
  final int amount;
  final String currencyCode;
  final String category;
  final String? description;
  final int blockId;

  Expense({
    required this.id,
    required this.amount,
    required this.currencyCode,
    required this.category,
    required this.description,
    required this.blockId,
  });

  factory Expense.fromJson(Map<String, dynamic> json) =>
      _$ExpenseFromJson(json);
}
