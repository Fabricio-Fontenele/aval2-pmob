import 'dart:io';

import 'package:shelf/shelf.dart';

String authClientAddress(Request request,
    {Set<String> trustedProxies = const {}}) {
  final info =
      request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
  final peer = info?.remoteAddress.address;
  if (peer == null) return 'unknown';
  if (!trustedProxies.contains(peer)) return peer;
  final forwarded = request.headers['x-forwarded-for'];
  if (forwarded == null || forwarded.length > 1024) return peer;
  var current = peer;
  for (final entry in forwarded.split(',').reversed) {
    if (!trustedProxies.contains(current)) break;
    final address = InternetAddress.tryParse(entry.trim());
    if (address == null) return peer;
    current = address.address;
  }
  return current;
}
