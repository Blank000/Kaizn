import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:googleapis/drive/v3.dart' as drive;

import '../constants/ai_config.dart';

/// Wraps Google Sign-In with the scopes we need (email + Drive AppData).
/// Single static instance — the underlying SDK manages session persistence,
/// so silent restoration on app start works automatically once we've called
/// [trySilentSignIn] in `main()`.
///
/// The Calendar scope is NOT in the base list — it's requested incrementally
/// via [requestCalendarAccess] when the user flips "Connect Google Calendar"
/// in Settings, so plain sign-in never over-asks.
class AuthService {
  AuthService._();

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const [
      'email',
      drive.DriveApi.driveAppdataScope,
    ],
    // Required on Android for an ID token, which is how Pico's server knows
    // who is asking. Only set once a real web client id exists - a wrong one
    // breaks Android sign-in entirely. See lib/core/constants/ai_config.dart.
    serverClientId:
        kGoogleServerClientId.isEmpty ? null : kGoogleServerClientId,
  );

  /// A Google ID token for the signed-in user, for Pico's server to verify.
  ///
  /// ID tokens live about an hour. [refresh] forces a new one - the AI
  /// client uses it once after the server says "expired", then gives up.
  static Future<String?> idToken({bool refresh = false}) async {
    try {
      var user = _googleSignIn.currentUser ??
          await _googleSignIn.signInSilently();
      if (user == null) return null;
      if (refresh) {
        user = await _googleSignIn.signInSilently(reAuthenticate: true) ??
            user;
      }
      return (await user.authentication).idToken;
    } catch (_) {
      return null;
    }
  }

  static GoogleSignIn get instance => _googleSignIn;

  static GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  /// Incremental consent for the full Calendar scope (read other calendars
  /// for the timeline overlay + manage the app's own Zuzu calendar +
  /// edit the user's solo events). Returns true when granted.
  static Future<bool> requestCalendarAccess() async {
    if (_googleSignIn.currentUser == null) {
      await _googleSignIn.signIn();
      if (_googleSignIn.currentUser == null) return false;
    }
    try {
      return await _googleSignIn
          .requestScopes([gcal.CalendarApi.calendarScope]);
    } catch (_) {
      return false;
    }
  }

  /// Attempt to restore a previously signed-in user without UI. Call from
  /// `main()` so the router can decide /login vs /home on first frame.
  static Future<GoogleSignInAccount?> trySilentSignIn() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (_) {
      return null;
    }
  }

  static Future<GoogleSignInAccount?> signIn() async {
    return _googleSignIn.signIn();
  }

  static Future<void> signOut() async {
    await _googleSignIn.disconnect();
    await _googleSignIn.signOut();
  }
}
