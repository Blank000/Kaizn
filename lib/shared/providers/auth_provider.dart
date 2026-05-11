import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/services/auth_service.dart';

/// Streams the current GoogleSignInAccount for UI watchers (e.g., Settings
/// to display avatar/email).
final currentUserProvider = StreamProvider<GoogleSignInAccount?>((ref) {
  // Seed with the current value so first frame doesn't show "loading"
  // unnecessarily.
  return AuthService.instance.onCurrentUserChanged.asBroadcastStream();
});

/// Listenable wrapper passed to GoRouter's `refreshListenable` so the
/// auth-aware redirect re-evaluates when the user signs in or out.
class AuthListenable extends ChangeNotifier {
  late final StreamSubscription _sub;

  AuthListenable() {
    _sub = AuthService.instance.onCurrentUserChanged.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final authListenableProvider = Provider<AuthListenable>((ref) {
  final l = AuthListenable();
  ref.onDispose(l.dispose);
  return l;
});
