import 'package:intl/intl.dart';
import 'package:trip_viewer/models/saved_trip.dart';
import 'package:trip_viewer/models/trip_plan.dart';

String formatDayAsText({
  required String tripTitle,
  required String tripId,
  required TripProvider provider,
  required DateTime date,
  required Section section,
  required List<FlightBlock> flights,
  required List<PlaceBlock> hotels,
  required List<TransitBlock> transit,
  required Map<String, PlaceMetadata> placeMetadata,
  required Map<int, Expense> expensesById,
}) {
  final buf = StringBuffer();
  _writeHeader(buf, tripTitle: tripTitle, tripId: tripId, provider: provider);

  buf.writeln(
    '${DateFormat('EEEE').format(date)}, '
    '${DateFormat('MMMM d, yyyy').format(date)}',
  );
  if (section.heading.isNotEmpty) {
    buf.writeln(section.heading);
  }

  final sectionText = _textContainerToPlain(section.text);
  if (sectionText.isNotEmpty) {
    buf.writeln();
    buf.writeln(sectionText);
  }

  if (flights.isNotEmpty) {
    buf.writeln();
    buf.writeln('Flights:');
    for (final f in flights) {
      _writeFlight(buf, f, expensesById);
    }
  }

  if (hotels.isNotEmpty) {
    buf.writeln();
    buf.writeln('Lodging:');
    for (final h in hotels) {
      _writeHotel(buf, h, placeMetadata, expensesById);
    }
  }

  if (transit.isNotEmpty) {
    buf.writeln();
    buf.writeln('Transit:');
    for (final t in transit) {
      _writeTransit(buf, t, expensesById);
    }
  }

  final activities = section.blocks.toList();
  if (activities.isNotEmpty) {
    buf.writeln();
    buf.writeln('Activities:');
    for (final b in activities) {
      _writeActivity(buf, b, placeMetadata, expensesById);
    }
  }

  return buf.toString().trimRight();
}

String formatUnscheduledSectionAsText({
  required String tripTitle,
  required String tripId,
  required TripProvider provider,
  required Section section,
  required Map<String, PlaceMetadata> placeMetadata,
  required Map<int, Expense> expensesById,
}) {
  final buf = StringBuffer();
  _writeHeader(buf, tripTitle: tripTitle, tripId: tripId, provider: provider);

  buf.writeln(section.heading.isEmpty ? 'Unscheduled' : section.heading);

  final sectionText = _textContainerToPlain(section.text);
  if (sectionText.isNotEmpty) {
    buf.writeln();
    buf.writeln(sectionText);
  }

  if (section.blocks.isNotEmpty) {
    buf.writeln();
    for (final b in section.blocks) {
      _writeActivity(buf, b, placeMetadata, expensesById);
    }
  }

  return buf.toString().trimRight();
}

void _writeHeader(
  StringBuffer buf, {
  required String tripTitle,
  required String tripId,
  required TripProvider provider,
}) {
  buf.writeln(tripTitle);
  buf.writeln('Trip ID: $tripId (${provider.displayName})');
  buf.writeln();
}

void _writeFlight(
  StringBuffer buf,
  FlightBlock f,
  Map<int, Expense> expensesById,
) {
  final from = '${f.depart.airport.iata} ${_formatTime(f.depart.time)}';
  final to = '${f.arrive.airport.iata} ${_formatTime(f.arrive.time)}';
  buf.writeln('- ${f.flightInfo.displayName}: $from -> $to');
  buf.writeln('    ${f.depart.airport.name} -> ${f.arrive.airport.name}');
  if (f.depart.date != f.arrive.date) {
    buf.writeln(
      '    Depart ${_formatDate(f.depart.date)}, '
      'arrive ${_formatDate(f.arrive.date)}',
    );
  }
  if (f.confirmationNumber != null && f.confirmationNumber!.isNotEmpty) {
    buf.writeln('    Confirmation: ${f.confirmationNumber}');
  }
  _writeExpense(buf, f.expenseId, expensesById);
}

void _writeHotel(
  StringBuffer buf,
  PlaceBlock h,
  Map<String, PlaceMetadata> placeMetadata,
  Map<int, Expense> expensesById,
) {
  buf.writeln('- ${h.place.name}');
  if (h.place.formattedAddress.isNotEmpty) {
    buf.writeln('    ${h.place.formattedAddress}');
  }
  final hotel = h.hotel;
  if (hotel != null) {
    final checkIn = hotel.checkIn;
    final checkOut = hotel.checkOut;
    if (checkIn != null && checkOut != null) {
      buf.writeln(
        '    Check-in ${_formatDate(checkIn)}, '
        'check-out ${_formatDate(checkOut)}',
      );
    }
    if (hotel.confirmationNumber != null &&
        hotel.confirmationNumber!.isNotEmpty) {
      buf.writeln('    Confirmation: ${hotel.confirmationNumber}');
    }
  }
  _writeExpense(buf, h.expenseId, expensesById);
}

void _writeTransit(
  StringBuffer buf,
  TransitBlock t,
  Map<int, Expense> expensesById,
) {
  final departTime = _formatTime(t.depart.time);
  final arriveTime = _formatTime(t.arrive.time);
  final from = departTime.isEmpty
      ? t.depart.place.name
      : '${t.depart.place.name} ($departTime)';
  final to = arriveTime.isEmpty
      ? t.arrive.place.name
      : '${t.arrive.place.name} ($arriveTime)';
  final label = t.carrier?.isNotEmpty == true ? '${t.type} - ${t.carrier}' : t.type;
  buf.writeln('- $label: $from -> $to');
  if (t.confirmationNumber != null && t.confirmationNumber!.isNotEmpty) {
    buf.writeln('    Confirmation: ${t.confirmationNumber}');
  }
  _writeExpense(buf, t.expenseId, expensesById);
}

void _writeActivity(
  StringBuffer buf,
  Block b,
  Map<String, PlaceMetadata> placeMetadata,
  Map<int, Expense> expensesById,
) {
  if (b is PlaceBlock) {
    final time = _formatTime(b.startTime);
    final endTime = _formatTime(b.endTime);
    final timeLabel = time.isEmpty
        ? ''
        : endTime.isEmpty
            ? '$time '
            : '$time-$endTime ';
    buf.writeln('- $timeLabel${b.place.name}');
    if (b.place.formattedAddress.isNotEmpty) {
      buf.writeln('    ${b.place.formattedAddress}');
    }
    final description = b.description?.trim();
    if (description != null && description.isNotEmpty) {
      buf.writeln('    $description');
    }
    final blockText = _textContainerToPlain(b.text);
    if (blockText.isNotEmpty) {
      for (final line in blockText.split('\n')) {
        buf.writeln('    $line');
      }
    }
    _writeExpense(buf, b.expenseId, expensesById);
  } else if (b is NoteBlock) {
    final note = _textContainerToPlain(b.text);
    if (note.isNotEmpty) {
      buf.writeln('- Note:');
      for (final line in note.split('\n')) {
        buf.writeln('    $line');
      }
    }
  }
}

void _writeExpense(
  StringBuffer buf,
  int? expenseId,
  Map<int, Expense> expensesById,
) {
  if (expenseId == null) return;
  final expense = expensesById[expenseId];
  if (expense == null) return;
  buf.writeln('    Cost: ${expense.amount.format()}');
}

String _textContainerToPlain(TextContainer? container) {
  if (container == null) return '';
  return container.ops.map((op) => op.insert).join().trim();
}

String _formatTime(String? time) {
  if (time == null || time.isEmpty) return '';
  try {
    return DateFormat('HH:mm').format(DateTime.parse('2024-01-01T$time'));
  } catch (_) {
    return time;
  }
}

String _formatDate(String date) {
  try {
    return DateFormat('EEE, MMM d').format(DateTime.parse(date));
  } catch (_) {
    return date;
  }
}
