import 'package:json_annotation/json_annotation.dart';
import 'amount.dart';

part 'trip_plan.g.dart';

@JsonSerializable()
class TripPlanResponse {
  final TripPlan tripPlan;
  final Resources resources;

  const TripPlanResponse({required this.tripPlan, required this.resources});
  factory TripPlanResponse.fromJson(Map<String, dynamic> json) =>
      TripPlanResponse(
        tripPlan: TripPlan.fromJson(_jsonMap(json['tripPlan'])),
        resources: Resources.fromJson(_jsonMap(json['resources'])),
      );
}

@JsonSerializable()
class PlaceMetadata {
  final int id;
  @JsonKey(defaultValue: '')
  final String name;
  @JsonKey(defaultValue: '')
  final String placeId;
  final String? generatedDescription;
  final String? description;
  final double? rating;
  final int? numRatings;
  @JsonKey(defaultValue: <String>[])
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
  factory PlaceMetadata.fromJson(Map<String, dynamic> json) => PlaceMetadata(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: _stringValue(json['name']),
        placeId: _stringValue(json['placeId']),
        generatedDescription: _optionalString(json['generatedDescription']),
        description: _optionalString(json['description']),
        imageKeys: _stringList(json['imageKeys'] ?? json['image_keys']),
        rating: (json['rating'] as num?)?.toDouble(),
        numRatings: (json['numRatings'] as num?)?.toInt(),
      );
}

@JsonSerializable()
class Resources {
  final List<PlaceMetadata> placeMetadata;

  Resources({required this.placeMetadata});
  factory Resources.fromJson(Map<String, dynamic> json) => Resources(
        placeMetadata: _jsonList(json['placeMetadata'])
            .whereType<Map>()
            .map((e) => PlaceMetadata.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

@JsonSerializable()
class TripPlan {
  @JsonKey(defaultValue: '')
  final String title;
  final int viewCount;
  final Itinerary itinerary;

  const TripPlan({
    required this.title,
    this.viewCount = 0,
    required this.itinerary,
  });

  List<Expense> get expenses => itinerary.budget.expenses;

  factory TripPlan.fromJson(Map<String, dynamic> json) => TripPlan(
        title: json['title'] as String? ?? '',
        viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
        itinerary: Itinerary.fromJson(_jsonMap(json['itinerary'])),
      );
}

@JsonSerializable()
class Itinerary {
  final List<Section> sections;
  final Budget budget;
  final Map<String, dynamic> options;

  const Itinerary({
    required this.sections,
    required this.budget,
    required this.options,
  });
  factory Itinerary.fromJson(Map<String, dynamic> json) => Itinerary(
        sections: _jsonList(json['sections'])
            .whereType<Map>()
            .map((e) => Section.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        budget: Budget.fromJson(_jsonMap(json['budget'])),
        options: _jsonMap(json['options']),
      );
}

@JsonSerializable()
class PaidByUser {
  @JsonKey(defaultValue: '')
  final String type;
  final int id;

  PaidByUser({required this.type, required this.id});

  factory PaidByUser.fromJson(Map<String, dynamic> json) => PaidByUser(
        type: json['type'] as String? ?? '',
        id: (json['id'] as num?)?.toInt() ?? 0,
      );
}

@JsonSerializable()
class SplitWith {
  @JsonKey(defaultValue: '')
  final String type;
  @JsonKey(fromJson: _usersFromJson)
  final List<dynamic> users;

  SplitWith({required this.type, required this.users});

  factory SplitWith.fromJson(Map<String, dynamic> json) =>
      _$SplitWithFromJson(json);

  static List<dynamic> _usersFromJson(List<dynamic>? json) {
    return json ?? [];
  }
}

@JsonSerializable()
class Payment {
  Payment();

  factory Payment.fromJson(Map<String, dynamic> json) =>
      _$PaymentFromJson(json);
}

@JsonSerializable()
class Budget {
  @JsonKey(fromJson: _amountFromJson)
  final Amount amount;
  final List<Expense> expenses;
  final List<Payment> payments;
  final bool simplifyDebt;

  Budget({
    required this.amount,
    required this.expenses,
    required this.payments,
    required this.simplifyDebt,
  });
  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
        amount: _amountFromJson(_optionalJsonMap(json['amount'])),
        expenses: _jsonList(json['expenses'])
            .whereType<Map>()
            .map((e) => _tryExpenseFromJson(Map<String, dynamic>.from(e)))
            .nonNulls
            .toList(),
        payments: _jsonList(json['payments'])
            .whereType<Map>()
            .map((e) => Payment.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        simplifyDebt: json['simplifyDebt'] as bool? ?? false,
      );

  static Amount _amountFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return Amount(amount: 0.0, currencyCode: 'USD');
    }
    return Amount.fromJson(json);
  }
}

List<Section> getSections(List<dynamic> json) {
  return json.map((section) => Section.fromJson(section)).toList();
}

@JsonSerializable()
class Section {
  @JsonKey(defaultValue: '')
  final String heading;
  final List<Block> blocks;
  final String? date;
  final TextContainer? text;

  const Section({
    required this.heading,
    required this.date,
    required this.blocks,
    this.text,
  });
  factory Section.fromJson(Map<String, dynamic> json) => Section(
        heading: json['heading'] as String? ?? '',
        date: json['date'] as String?,
        blocks: getBlocks(_jsonList(json['blocks'])),
        text: json['text'] == null
            ? null
            : TextContainer.fromJson(_jsonMap(json['text'])),
      );
}

List<Block> getBlocks(List<dynamic> json) {
  return json.whereType<Map>().map((block) {
    final blockJson = Map<String, dynamic>.from(block);
    try {
      return getBlock(blockJson);
    } catch (_) {
      return Block.fromJson(blockJson);
    }
  }).toList();
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
  @JsonKey(defaultValue: '')
  final String type;
  final List<String> imageKeys;
  final Expense? price;
  final int? expenseId;

  Block(
      {required this.type,
      this.imageKeys = const [],
      this.price,
      this.expenseId});

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
    return Block(
        type: json['type'] as String? ?? '',
        imageKeys: _stringList(json['imageKeys'] ?? json['image_keys']),
        price:
            json['price'] == null ? null : _tryExpenseFromJson(json['price']),
        expenseId: (json['expenseId'] as num?)?.toInt());
  }
}

@JsonSerializable()
class PlaceBlock extends Block {
  final GooglePlace place;
  final Hotel? hotel;
  final String? startTime;
  final String? endTime;
  final String? description;
  final TextContainer? text;

  PlaceBlock({
    required this.place,
    required this.hotel,
    required this.startTime,
    required this.endTime,
    required this.description,
    this.text,
    super.imageKeys,
    super.price,
    super.expenseId,
  }) : super(type: 'place');

  factory PlaceBlock.fromJson(Map<String, dynamic> json) => PlaceBlock(
        place: GooglePlace.fromJson(_jsonMap(json['place'])),
        hotel: json['hotel'] == null
            ? null
            : Hotel.fromJson(_jsonMap(json['hotel'])),
        startTime: _optionalString(json['startTime']),
        endTime: _optionalString(json['endTime']),
        description: _optionalString(json['description']),
        text: json['text'] == null
            ? null
            : TextContainer.fromJson(_jsonMap(json['text'])),
        imageKeys: _stringList(json['imageKeys'] ?? json['image_keys']),
        price: _tryExpenseFromJson(json['price']),
        expenseId: (json['expenseId'] as num?)?.toInt(),
      );
}

@JsonSerializable()
class TextOps {
  @JsonKey(defaultValue: '')
  final String insert;
  final dynamic attributes;

  TextOps({required this.insert, this.attributes});
  factory TextOps.fromJson(Map<String, dynamic> json) =>
      _$TextOpsFromJson(json);
}

@JsonSerializable()
class TextContainer {
  final List<TextOps> ops;
  TextContainer({required this.ops});
  factory TextContainer.fromJson(Map<String, dynamic> json) => TextContainer(
        ops: _jsonList(json['ops'])
            .whereType<Map>()
            .map((e) => TextOps.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

@JsonSerializable()
class NoteBlock extends Block {
  final TextContainer text;
  NoteBlock({required this.text, super.imageKeys, super.price, super.expenseId})
      : super(type: 'note');
  factory NoteBlock.fromJson(Map<String, dynamic> json) => NoteBlock(
        text: TextContainer.fromJson(_jsonMap(json['text'])),
        imageKeys: _stringList(json['imageKeys'] ?? json['image_keys']),
        price: _tryExpenseFromJson(json['price']),
        expenseId: (json['expenseId'] as num?)?.toInt(),
      );
}

@JsonSerializable()
class Airline {
  final String? iata;
  final String? icao;
  final String? name;
  final String? localizedName;

  Airline({
    required this.iata,
    required this.icao,
    required this.name,
    required this.localizedName,
  });

  factory Airline.fromJson(Map<String, dynamic> json) => Airline(
        iata: _optionalString(json['iata']),
        icao: _optionalString(json['icao']),
        name: _optionalString(json['name']),
        localizedName: _optionalString(json['localizedName']),
      );
}

@JsonSerializable()
class Photo {
  final int height;
  final int width;

  @JsonKey(name: 'photo_reference', defaultValue: '')
  final String photoReference;

  Photo(
      {required this.height,
      required this.width,
      required this.photoReference});

  factory Photo.fromJson(Map<String, dynamic> json) => _$PhotoFromJson(json);
}

@JsonSerializable()
class GooglePlace {
  @JsonKey(name: 'formatted_address', defaultValue: '')
  final String formattedAddress;
  @JsonKey(name: 'place_id', defaultValue: '')
  final String placeId;
  @JsonKey(defaultValue: '')
  final String name;
  final List<Photo>? photos;
  final String? url;
  final Geometry? geometry;

  GooglePlace({
    required this.formattedAddress,
    required this.name,
    required this.photos,
    required this.url,
    required this.placeId,
    this.geometry,
  });

  factory GooglePlace.fromJson(Map<String, dynamic> json) =>
      _$GooglePlaceFromJson(json);
}

@JsonSerializable()
class Geometry {
  final Location location;

  Geometry({required this.location});

  factory Geometry.fromJson(Map<String, dynamic> json) =>
      _$GeometryFromJson(json);
}

@JsonSerializable()
class Location {
  final double lat;
  final double lng;

  Location({required this.lat, required this.lng});

  factory Location.fromJson(Map<String, dynamic> json) =>
      _$LocationFromJson(json);
}

@JsonSerializable()
class Airport {
  @JsonKey(defaultValue: '')
  final String iata;
  @JsonKey(defaultValue: '')
  final String name;
  @JsonKey(defaultValue: '')
  final String cityName;
  final GooglePlace? googlePlace;

  Airport(
      {required this.iata,
      required this.name,
      required this.cityName,
      this.googlePlace});

  factory Airport.fromJson(Map<String, dynamic> json) => Airport(
        iata: _stringValue(json['iata']),
        name: _stringValue(json['name']),
        cityName: _stringValue(json['cityName']),
        googlePlace: json['googlePlace'] == null
            ? null
            : GooglePlace.fromJson(_jsonMap(json['googlePlace'])),
      );
}

@JsonSerializable()
class DepartArrive {
  @JsonKey(defaultValue: '')
  final String date;
  @JsonKey(defaultValue: '')
  final String time;
  final Airport airport;

  DepartArrive({required this.date, required this.time, required this.airport});

  factory DepartArrive.fromJson(Map<String, dynamic> json) => DepartArrive(
        date: _stringValue(json['date']),
        time: _stringValue(json['time']),
        airport: Airport.fromJson(_jsonMap(json['airport'])),
      );
}

@JsonSerializable()
class DepartArrivePlace {
  @JsonKey(defaultValue: '')
  final String date;
  final String? time;
  final GooglePlace place;

  DepartArrivePlace(
      {required this.date, required this.time, required this.place});

  factory DepartArrivePlace.fromJson(Map<String, dynamic> json) =>
      DepartArrivePlace(
        date: _stringValue(json['date']),
        time: _optionalString(json['time']),
        place: GooglePlace.fromJson(_jsonMap(json['place'])),
      );
}

@JsonSerializable()
class FlightInfo {
  final Airline airline;
  final int number;

  FlightInfo({
    required this.airline,
    required this.number,
  });

  factory FlightInfo.fromJson(Map<String, dynamic> json) => FlightInfo(
        airline: Airline.fromJson(_jsonMap(json['airline'])),
        number: (json['number'] as num?)?.toInt() ?? 0,
      );

  String? get airlineCode {
    final iata = airline.iata?.trim();
    if (iata != null && iata.isNotEmpty) return iata.toUpperCase();

    final icao = airline.icao?.trim();
    if (icao != null && icao.isNotEmpty) return icao.toUpperCase();

    return null;
  }

  String get flightNumber {
    final code = airlineCode;
    return code == null ? number.toString() : '$code$number';
  }

  String get displayName {
    final airlineName = airline.name?.trim();
    if (airlineName != null && airlineName.isNotEmpty) {
      return '$airlineName $number';
    }

    final localizedName = airline.localizedName?.trim();
    if (localizedName != null && localizedName.isNotEmpty) {
      return '$localizedName $number';
    }

    return flightNumber;
  }
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

  factory FlightBlock.fromJson(Map<String, dynamic> json) => FlightBlock(
        flightInfo: FlightInfo.fromJson(_jsonMap(json['flightInfo'])),
        depart: DepartArrive.fromJson(_jsonMap(json['depart'])),
        arrive: DepartArrive.fromJson(_jsonMap(json['arrive'])),
        confirmationNumber: _optionalString(json['confirmationNumber']),
        imageKeys: _stringList(json['imageKeys'] ?? json['image_keys']),
        price: _tryExpenseFromJson(json['price']),
        expenseId: (json['expenseId'] as num?)?.toInt(),
      );
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

  factory Hotel.fromJson(Map<String, dynamic> json) => Hotel(
        checkIn: _optionalString(json['checkIn']),
        checkOut: _optionalString(json['checkOut']),
        confirmationNumber: _optionalString(json['confirmationNumber']),
      );
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

  factory TransitBlock.fromJson(Map<String, dynamic> json) => TransitBlock(
        depart: DepartArrivePlace.fromJson(_jsonMap(json['depart'])),
        arrive: DepartArrivePlace.fromJson(_jsonMap(json['arrive'])),
        confirmationNumber: _optionalString(json['confirmationNumber']),
        carrier: _optionalString(json['carrier']),
        type: _stringValue(json['type']),
        price: _tryExpenseFromJson(json['price']),
        expenseId: (json['expenseId'] as num?)?.toInt(),
      );
}

@JsonSerializable()
class Expense {
  final int id;
  @JsonKey(fromJson: _amountFromJson)
  final Amount amount;
  final String? category;
  final String? description;
  final String? date;
  final int? blockId;
  final int paidByUserId;
  final PaidByUser paidByUser;
  final SplitWith splitWith;
  final String? associatedDate;

  Expense({
    required this.id,
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
    this.blockId,
    required this.paidByUserId,
    required this.paidByUser,
    required this.splitWith,
    required this.associatedDate,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: (json['id'] as num?)?.toInt() ?? 0,
        amount: _amountFromJson(json['amount']),
        category: json['category'] as String?,
        description: json['description'] as String?,
        date: json['date'] as String?,
        blockId: (json['blockId'] as num?)?.toInt(),
        paidByUserId: (json['paidByUserId'] as num?)?.toInt() ?? 0,
        paidByUser: PaidByUser.fromJson(_jsonMap(json['paidByUser'])),
        splitWith: SplitWith.fromJson(_jsonMap(json['splitWith'])),
        associatedDate: json['associatedDate'] as String?,
      );

  static Amount _amountFromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return Amount(amount: 0.0, currencyCode: 'USD');
    }
    return Amount.fromJson(json);
  }
}

Expense? _tryExpenseFromJson(dynamic value) {
  if (value is! Map) return null;
  try {
    return Expense.fromJson(Map<String, dynamic>.from(value));
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> _jsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

Map<String, dynamic>? _optionalJsonMap(dynamic value) {
  if (value == null) return null;
  return _jsonMap(value);
}

List<dynamic> _jsonList(dynamic value) {
  if (value is List) return value;
  return const [];
}

List<String> _stringList(dynamic value) {
  return _jsonList(value).whereType<String>().toList();
}

String _stringValue(dynamic value) => value is String ? value : '';

String? _optionalString(dynamic value) => value is String ? value : null;
