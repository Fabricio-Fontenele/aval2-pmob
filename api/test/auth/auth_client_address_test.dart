import 'dart:io';

import 'package:lost_and_found_api/src/auth/auth_client_address.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class _PeerInfo implements HttpConnectionInfo {
  @override
  final InternetAddress remoteAddress;
  @override
  int get remotePort => 12345;
  @override
  int get localPort => 8080;

  _PeerInfo(String address) : remoteAddress = InternetAddress(address);
}

void main() {
  Request request(String? peer, String? forwarded) => Request(
        'POST',
        Uri.parse('http://localhost/auth/login'),
        context: {
          if (peer != null) 'shelf.io.connection_info': _PeerInfo(peer)
        },
        headers: {if (forwarded != null) 'x-forwarded-for': forwarded},
      );

  test('ignores forged forwarded headers from an untrusted connection', () {
    expect(authClientAddress(request('192.0.2.1', '203.0.113.9')), '192.0.2.1');
    expect(authClientAddress(request(null, '203.0.113.9')), 'unknown');
  });

  test(
      'walks trusted proxies from right to left and ignores spoofed left entries',
      () {
    expect(
        authClientAddress(
            request('127.0.0.1', '198.51.100.99, 192.0.2.5, 127.0.0.2'),
            trustedProxies: {'127.0.0.1', '127.0.0.2'}),
        '192.0.2.5');
  });

  test('malformed forwarded addresses fall back to the trusted peer', () {
    expect(
        authClientAddress(request('127.0.0.1', 'invalid-address'),
            trustedProxies: {'127.0.0.1'}),
        '127.0.0.1');
  });
}
