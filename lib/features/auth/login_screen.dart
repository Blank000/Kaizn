import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _signingIn = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _signingIn = true;
      _error = null;
    });
    try {
      await AuthService.signIn();
      // Successful sign-in fires onCurrentUserChanged; the router redirect
      // takes us off this screen automatically.
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Sign-in failed. Try again.');
      }
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appCardSurface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 64,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Habit Reward Tracker',
                style: AppTypography.heading1.copyWith(fontSize: 28),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Sign in to save your data and back it up to Google Drive.',
                style: AppTypography.body.copyWith(
                  color: context.appTextSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _signingIn ? null : _signIn,
                  icon: _signingIn
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.login_rounded),
                  label: Text(
                      _signingIn ? 'Signing in…' : 'CONTINUE WITH GOOGLE'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.missedRed,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Your data backs up to a hidden folder in your own Google Drive. Only this app can read it.',
                style: AppTypography.caption.copyWith(
                  color: context.appTextTertiary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
