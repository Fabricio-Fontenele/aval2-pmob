abstract interface class SessionTokenStore {
  Future<String?> readToken();

  Future<void> writeToken(String token);

  Future<void> deleteToken();
}
