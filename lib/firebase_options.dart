// Local-only build: Firebase has been disabled intentionally.
class DefaultFirebaseOptions {
  static Never get currentPlatform {
    throw UnsupportedError(
      'Firebase is disabled in local-data mode. Enable Firebase dependencies and regenerate this file if needed.',
    );
  }
}
