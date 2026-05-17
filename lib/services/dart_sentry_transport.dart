import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';

const _sendTimeout = Duration(seconds: 10);

/// Sends Sentry envelopes through Dart HTTP so delivery shows up in
/// app logs. The default native transport hides whether events ever
/// reach the server, which made debugging silent drops impossible.
class DartSentryTransport implements Transport {
  DartSentryTransport(this._options, {http.Client? client})
      : _client = client ?? http.Client(),
        _dsn = Dsn.parse(_options.dsn ?? '');

  final SentryOptions _options;
  final http.Client _client;
  final Dsn _dsn;

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    envelope.header.sentAt = DateTime.now().toUtc();
    final envelopeId = envelope.header.eventId;
    log('[Sentry] sending envelope id=$envelopeId');

    final http.Response response;
    try {
      final body = await _envelopeBytes(envelope);
      final request = http.Request('POST', _dsn.postUri)
        ..headers.addAll(_headers())
        ..bodyBytes = body;
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(_sendTimeout);
    } catch (error, stackTrace) {
      log('[Sentry] send failed: $error');
      _options.log(
        SentryLevel.error,
        'Failed to send Sentry envelope: $error',
        exception: error,
        stackTrace: stackTrace,
      );
      return SentryId.empty();
    }

    if (response.statusCode == 200) {
      log('[Sentry] sent envelope id=$envelopeId');
      return envelopeId;
    }

    log('[Sentry] send failed status=${response.statusCode} '
        'body=${response.body}');
    return SentryId.empty();
  }

  Future<Uint8List> _envelopeBytes(SentryEnvelope envelope) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk
        in envelope.envelopeStream(_options).timeout(_sendTimeout)) {
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  Map<String, String> _headers() {
    var auth = 'Sentry sentry_version=7, '
        'sentry_client=${_options.sentryClientName}, '
        'sentry_key=${_dsn.publicKey}';
    final secretKey = _dsn.secretKey;
    if (secretKey != null) {
      auth += ', sentry_secret=$secretKey';
    }
    return {
      'Content-Type': 'application/x-sentry-envelope',
      'User-Agent': _options.sentryClientName,
      'X-Sentry-Auth': auth,
    };
  }
}
