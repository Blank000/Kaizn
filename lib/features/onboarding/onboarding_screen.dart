import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/app_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';
import '../milestones/widgets/task_form_sheet.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      emoji: '🎯',
      title: 'Track what matters',
      body:
          'Habits, goals, projects — break them into tasks. Every task you check off earns points.',
    ),
    _OnboardingPage(
      emoji: '🔥',
      title: 'Build streaks',
      body:
          "Log at least one real task each day to keep your streak alive. Need a rest? Mark a task as a Skip — it preserves your streak with no penalty.",
    ),
    _OnboardingPage(
      emoji: '🎁',
      title: 'Unlock real rewards',
      body:
          "Define rewards you actually want — a cheat meal, a movie night, a new book. Earn enough points and they're yours to claim. Auto-badges show up along the way.",
    ),
    _OnboardingPage(
      emoji: '🚀',
      title: "Ready when you are",
      body:
          "We've created an Inbox for quick captures. Add your first task to get going, or jump in and explore.",
    ),
  ];

  bool get _isLast => _currentPage == _pages.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (!_isLast) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish({bool addTaskAfter = false}) async {
    await AppPrefs.markOnboardingComplete();
    if (!mounted) return;
    context.go('/home');
    if (addTaskAfter) {
      // Wait briefly so the home screen is mounted before opening the sheet.
      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted) {
        showTaskFormSheet(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appCardSurface,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button (top right)
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: () => _finish(),
                  child: Text(
                    'SKIP',
                    style: AppTypography.caption.copyWith(
                      color: context.appTextTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _pages[i],
              ),
            ),

            // Page indicator dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? AppColors.primary
                        : context.appBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Bottom CTA — varies by page
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _isLast ? _buildFinalCtas() : _buildNextButton(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _next,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text('NEXT'),
      ),
    );
  }

  Widget _buildFinalCtas() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _finish(addTaskAfter: true),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('ADD FIRST TASK'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _finish(),
          child: Text(
            'Just take me in',
            style: AppTypography.button.copyWith(color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final String emoji;
  final String title;
  final String body;

  const _OnboardingPage({
    required this.emoji,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 80)),
          const SizedBox(height: 32),
          Text(
            title,
            style: AppTypography.heading1.copyWith(fontSize: 28),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style: AppTypography.body.copyWith(
              color: context.appTextSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
