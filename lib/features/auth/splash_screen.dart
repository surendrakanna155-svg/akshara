import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../features/school_completion/school_branding_theme_provider.dart';
import '../../core/config/environment_provider.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../router/app_router.dart';
import '../../router/route_names.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'auth_models.dart';
import 'auth_provider.dart';

/// P-01 Splash — restores persisted session, then routes by auth + role.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  /// Minimum time the splash stays up.
  ///
  /// This is an anti-flicker floor, NOT a brand timer. `resolveSession()` reads
  /// a persisted session from local storage and typically returns in tens of
  /// milliseconds; without a floor the splash would appear and vanish inside a
  /// frame or two, which reads as a glitch. 400ms is enough to register as a
  /// deliberate transition and is below the ~1s threshold where a wait starts
  /// to feel like waiting.
  ///
  /// It used to be 2 seconds, combined with `Future.wait` — which takes the
  /// MAXIMUM of its futures, so it was a hard floor rather than a timeout. That
  /// added a guaranteed 2000ms to every single cold start, on top of native and
  /// Dart VM startup, on a product whose own budget is <3s cold start on a
  /// modest phone. If a longer deliberate brand moment is ever wanted it should
  /// be first-launch-only, not a tax on every launch.
  static const Duration splashDuration = Duration(milliseconds: 400);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait<void>([
      ref.read(authProvider.notifier).resolveSession(),
      Future<void>.delayed(SplashScreen.splashDuration),
    ]);

    if (!mounted) {
      return;
    }

    final auth = ref.read(authProvider);
    context.go(_destinationForAuth(auth));
  }

  String _destinationForAuth(AuthState auth) {
    if (!auth.isAuthenticated) {
      final qaLogin = ref.read(isQaLoginEnabledProvider);
      return qaLogin ? RouteNames.qaLogin : RouteNames.login;
    }

    return homeRouteForAuth(auth);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final schoolName = ref.watch(schoolDisplayNameProvider);
    final logoUrl = ref.watch(schoolLogoUrlProvider);

    return Scaffold(
      key: QaTestKeys.splash,
      backgroundColor: colors.primary,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: colors.onPrimary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: logoUrl != null && logoUrl.startsWith('http')
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.network(logoUrl, fit: BoxFit.cover),
                        )
                      : Icon(
                          Icons.school_rounded,
                          size: 56,
                          color: colors.primary,
                        ),
                ),
                const SizedBox(height: AksharaSpacing.s6),
                Text(
                  schoolName.isNotEmpty ? schoolName : AppConstants.appName,
                  style: text.headlineMedium.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AksharaSpacing.s2),
                Text(
                  AppConstants.appName,
                  style: text.bodyLarge.copyWith(
                    color: colors.onPrimary.withValues(alpha: 0.88),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AksharaSpacing.s1),
                // The positioning line. On a school's first cold start this is
                // the one moment the product gets to say what it is, before any
                // dashboard has loaded.
                Text(
                  AppConstants.appTagline,
                  style: text.bodySmall.copyWith(
                    color: colors.onPrimary.withValues(alpha: 0.70),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AksharaSpacing.s8),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colors.onPrimary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
