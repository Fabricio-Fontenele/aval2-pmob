/// Supplies the stored bearer credential to data adapters of other features.
///
/// It is the only authentication contract those adapters depend on: they send
/// the token and report its rejection, without reading or writing the store.
abstract interface class SessionTokenProvider {
  /// Returns the stored session token, or `null` when no session is available.
  Future<String?> getSessionToken();

  /// Discards [rejectedToken] when it is still the stored one.
  ///
  /// Returns whether it was discarded, so a newer session survives a late
  /// rejection of the previous token.
  Future<bool> invalidateSession(String rejectedToken);
}
