import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

/// Wraps Google Sign-In with the scopes we need (email + Drive AppData).
/// Single static instance — the underlying SDK manages session persistence,
/// so silent restoration on app start works automatically once we've called
/// [trySilentSignIn] in `main()`.
class AuthService {
  AuthService._();

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const [
      'email',
      drive.DriveApi.driveAppdataScope,
    ],
  );

  static GoogleSignIn get instance => _googleSignIn;

  static GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

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
