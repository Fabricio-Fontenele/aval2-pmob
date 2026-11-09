abstract interface class SessionTokenProvider {
  Future<String?> getSessionToken();

  Future<bool> invalidateSession(String rejectedToken);
}
