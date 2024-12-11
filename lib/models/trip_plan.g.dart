// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_plan.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TripPlanResponse _$TripPlanResponseFromJson(Map<String, dynamic> json) =>
    TripPlanResponse(
      tripPlan: TripPlan.fromJson(json['tripPlan'] as Map<String, dynamic>),
      resources: Resources.fromJson(json['resources'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$TripPlanResponseToJson(TripPlanResponse instance) =>
    <String, dynamic>{
      'tripPlan': instance.tripPlan,
      'resources': instance.resources,
    };

PlaceMetadata _$PlaceMetadataFromJson(Map<String, dynamic> json) =>
    PlaceMetadata(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      placeId: json['placeId'] as String,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$PlaceMetadataToJson(PlaceMetadata instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'placeId': instance.placeId,
      'description': instance.description,
    };

Resources _$ResourcesFromJson(Map<String, dynamic> json) => Resources(
      placeMetadata: (json['placeMetadata'] as List<dynamic>)
          .map((e) => PlaceMetadata.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ResourcesToJson(Resources instance) => <String, dynamic>{
      'placeMetadata': instance.placeMetadata,
    };

TripPlan _$TripPlanFromJson(Map<String, dynamic> json) => TripPlan(
      title: json['title'] as String,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      itinerary: Itinerary.fromJson(json['itinerary'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$TripPlanToJson(TripPlan instance) => <String, dynamic>{
      'title': instance.title,
      'viewCount': instance.viewCount,
      'itinerary': instance.itinerary,
    };

Itinerary _$ItineraryFromJson(Map<String, dynamic> json) => Itinerary(
      sections: (json['sections'] as List<dynamic>)
          .map((e) => Section.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ItineraryToJson(Itinerary instance) => <String, dynamic>{
      'sections': instance.sections,
    };

Section _$SectionFromJson(Map<String, dynamic> json) => Section(
      heading: json['heading'] as String,
      date: json['date'] as String?,
      blocks: (json['blocks'] as List<dynamic>)
          .map((e) => Block.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SectionToJson(Section instance) => <String, dynamic>{
      'heading': instance.heading,
      'blocks': instance.blocks,
      'date': instance.date,
    };

Block _$BlockFromJson(Map<String, dynamic> json) => Block(
      type: json['type'] as String,
      imageKeys: (json['imageKeys'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$BlockToJson(Block instance) => <String, dynamic>{
      'type': instance.type,
      'imageKeys': instance.imageKeys,
    };

PlaceBlock _$PlaceBlockFromJson(Map<String, dynamic> json) => PlaceBlock(
      place: GooglePlace.fromJson(json['place'] as Map<String, dynamic>),
      hotel: json['hotel'] == null
          ? null
          : Hotel.fromJson(json['hotel'] as Map<String, dynamic>),
      placeId: json['place_id'] as String?,
      imageKeys: (json['imageKeys'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$PlaceBlockToJson(PlaceBlock instance) =>
    <String, dynamic>{
      'imageKeys': instance.imageKeys,
      'place': instance.place,
      'hotel': instance.hotel,
      'place_id': instance.placeId,
    };

TextOps _$TextOpsFromJson(Map<String, dynamic> json) => TextOps(
      insert: json['insert'] as String,
      attributes: json['attributes'] as String?,
    );

Map<String, dynamic> _$TextOpsToJson(TextOps instance) => <String, dynamic>{
      'insert': instance.insert,
      'attributes': instance.attributes,
    };

TextContainer _$TextContainerFromJson(Map<String, dynamic> json) =>
    TextContainer(
      ops: (json['ops'] as List<dynamic>)
          .map((e) => TextOps.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$TextContainerToJson(TextContainer instance) =>
    <String, dynamic>{
      'ops': instance.ops,
    };

NoteBlock _$NoteBlockFromJson(Map<String, dynamic> json) => NoteBlock(
      text: TextContainer.fromJson(json['text'] as Map<String, dynamic>),
      imageKeys: (json['imageKeys'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$NoteBlockToJson(NoteBlock instance) => <String, dynamic>{
      'imageKeys': instance.imageKeys,
      'text': instance.text,
    };

Airline _$AirlineFromJson(Map<String, dynamic> json) => Airline(
      iata: json['iata'] as String,
      icao: json['icao'] as String,
      name: json['name'] as String,
      localizedName: json['localizedName'] as String,
    );

Map<String, dynamic> _$AirlineToJson(Airline instance) => <String, dynamic>{
      'iata': instance.iata,
      'icao': instance.icao,
      'name': instance.name,
      'localizedName': instance.localizedName,
    };

Photo _$PhotoFromJson(Map<String, dynamic> json) => Photo(
      height: (json['height'] as num).toInt(),
      width: (json['width'] as num).toInt(),
      photoReference: json['photo_reference'] as String,
    );

Map<String, dynamic> _$PhotoToJson(Photo instance) => <String, dynamic>{
      'height': instance.height,
      'width': instance.width,
      'photo_reference': instance.photoReference,
    };

GooglePlace _$GooglePlaceFromJson(Map<String, dynamic> json) => GooglePlace(
      formattedAddress: json['formatted_address'] as String,
      name: json['name'] as String,
      photos: (json['photos'] as List<dynamic>?)
          ?.map((e) => Photo.fromJson(e as Map<String, dynamic>))
          .toList(),
      url: json['url'] as String?,
    );

Map<String, dynamic> _$GooglePlaceToJson(GooglePlace instance) =>
    <String, dynamic>{
      'formatted_address': instance.formattedAddress,
      'name': instance.name,
      'photos': instance.photos,
      'url': instance.url,
    };

Airport _$AirportFromJson(Map<String, dynamic> json) => Airport(
      iata: json['iata'] as String,
      name: json['name'] as String,
      cityName: json['cityName'] as String,
      googlePlace:
          GooglePlace.fromJson(json['googlePlace'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AirportToJson(Airport instance) => <String, dynamic>{
      'iata': instance.iata,
      'name': instance.name,
      'cityName': instance.cityName,
      'googlePlace': instance.googlePlace,
    };

DepartArrive _$DepartArriveFromJson(Map<String, dynamic> json) => DepartArrive(
      date: json['date'] as String,
      time: json['time'] as String,
      airport: Airport.fromJson(json['airport'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DepartArriveToJson(DepartArrive instance) =>
    <String, dynamic>{
      'date': instance.date,
      'time': instance.time,
      'airport': instance.airport,
    };

FlightInfo _$FlightInfoFromJson(Map<String, dynamic> json) => FlightInfo(
      airline: Airline.fromJson(json['airline'] as Map<String, dynamic>),
      number: (json['number'] as num).toInt(),
    );

Map<String, dynamic> _$FlightInfoToJson(FlightInfo instance) =>
    <String, dynamic>{
      'airline': instance.airline,
      'number': instance.number,
    };

FlightBlock _$FlightBlockFromJson(Map<String, dynamic> json) => FlightBlock(
      flightInfo:
          FlightInfo.fromJson(json['flightInfo'] as Map<String, dynamic>),
      depart: DepartArrive.fromJson(json['depart'] as Map<String, dynamic>),
      arrive: DepartArrive.fromJson(json['arrive'] as Map<String, dynamic>),
      imageKeys: (json['imageKeys'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$FlightBlockToJson(FlightBlock instance) =>
    <String, dynamic>{
      'imageKeys': instance.imageKeys,
      'flightInfo': instance.flightInfo,
      'depart': instance.depart,
      'arrive': instance.arrive,
    };

Hotel _$HotelFromJson(Map<String, dynamic> json) => Hotel(
      checkIn: json['checkIn'] as String?,
      checkOut: json['checkOut'] as String?,
      confirmationNumber: json['confirmationNumber'] as String?,
    );

Map<String, dynamic> _$HotelToJson(Hotel instance) => <String, dynamic>{
      'checkIn': instance.checkIn,
      'checkOut': instance.checkOut,
      'confirmationNumber': instance.confirmationNumber,
    };
