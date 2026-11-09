abstract final class ApiBaseUrl {
  static const _loopbackHosts = {'localhost', '127.0.0.1', '::1', '[::1]'};

  static Uri fromEnvironment() {
    const address = String.fromEnvironment('API_BASE_URL');
    if (address.isEmpty) {
      throw StateError(
        'Set API_BASE_URL with --dart-define before assembling the HTTP repositories.',
      );
    }
    return normalize(Uri.parse(address));
  }

  static Uri normalize(Uri url) {
    final secure =
        url.scheme == 'https' ||
        (url.scheme == 'http' && _loopbackHosts.contains(url.host));
    if (!secure ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.hasQuery ||
        url.hasFragment) {
      throw ArgumentError(
        'API_BASE_URL must use HTTPS (or loopback HTTP) without credentials, query, or fragment.',
      );
    }
    return url.replace(
      path: url.path.endsWith('/') ? url.path : '${url.path}/',
    );
  }
}
