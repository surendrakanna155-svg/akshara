import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/environment_provider.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../router/app_router.dart';
import '../../router/route_names.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'auth_models.dart';
import 'auth_provider.dart';
import '../../theme/breakpoints.dart';

/// OTP verification step after P-03 login (mock).
class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.role,
  });

  final String phoneNumber;
  final UserRole? role;

  static const double _tabletBreakpoint = AksharaBreakpoints.tabletMinWidth;
  static const double _maxFormWidth = 400;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isVerifying = false;
  int _resendSeconds = 30;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  String get _maskedPhone {
    final digits = widget.phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) {
      return widget.phoneNumber;
    }
    return '+91 ${digits.substring(0, 2)}******${digits.substring(digits.length - 2)}';
  }

  UserRole get _pendingRole {
    return widget.role ??
        ref.read(authProvider).role ??
        ref.read(demoLoginRoleProvider);
  }

  Future<void> _verify() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit OTP')),
      );
      return;
    }

    setState(() => _isVerifying = true);
    final ok = await ref.read(authProvider.notifier).verifyOtp(otp);
    if (!mounted) {
      return;
    }
    setState(() => _isVerifying = false);

    if (ok) {
      final auth = ref.read(authProvider);
      context.go(homeRouteForRole(auth.role));
    } else {
      final demoAuth = ref.read(isDemoAuthEnabledProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            demoAuth
                ? 'Invalid OTP. Testing mode accepts $kMockValidOtp only.'
                : 'Invalid OTP or unregistered phone number.',
          ),
        ),
      );
    }
  }

  void _returnToLogin() {
    ref.read(authProvider.notifier).cancelOtpPending();
    context.go(RouteNames.login);
  }

  Future<void> _resend() async {
    final digits = widget.phoneNumber.replaceAll(RegExp(r'\D'), '');
    final demoAuth = ref.read(isDemoAuthEnabledProvider);
    final role = _pendingRole;
    await ref.read(authProvider.notifier).sendOtp(
          digits,
          demoAuth ? role : UserRole.parent,
        );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          demoAuth ? 'OTP resent (testing mode)' : 'OTP resent',
        ),
      ),
    );
    _startResendTimer();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final demoAuth = ref.watch(isDemoAuthEnabledProvider);
    final role = _pendingRole;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _returnToLogin();
        }
      },
      child: Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _returnToLogin,
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >=
                OtpVerificationScreen._tabletBreakpoint;
            final horizontalPadding = isTablet
                ? AksharaSpacing.tabletMargin
                : AksharaSpacing.mobileMargin;

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: OtpVerificationScreen._maxFormWidth,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    AksharaSpacing.s4,
                    horizontalPadding,
                    AksharaSpacing.s6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Verify OTP',
                        style: text.headlineSmall.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AksharaSpacing.s2),
                      Text(
                        'We sent a 6-digit code to $_maskedPhone',
                        style: text.bodyMedium.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AksharaSpacing.s2),
                      if (demoAuth)
                        Text(
                          'Testing as ${role.label}',
                          style: text.labelLarge.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: AksharaSpacing.s8),
                      TextFormField(
                        key: QaTestKeys.otpField,
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        textAlign: TextAlign.center,
                        style: text.headlineSmall.copyWith(
                          letterSpacing: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: InputDecoration(
                          hintText: '••••••',
                          border: OutlineInputBorder(
                            borderRadius: AksharaRadius.inputBorder,
                          ),
                        ),
                        onFieldSubmitted: (_) => _verify(),
                      ),
                      const SizedBox(height: AksharaSpacing.s6),
                      FilledButton(
                        key: QaTestKeys.otpVerifyButton,
                        onPressed: _isVerifying ? null : _verify,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: AksharaRadius.button,
                          ),
                        ),
                        child: _isVerifying
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.onPrimary,
                                ),
                              )
                            : const Text('Verify & continue'),
                      ),
                      const SizedBox(height: AksharaSpacing.s4),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            "Didn't receive the code?",
                            style: text.bodySmall.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            onPressed:
                                _resendSeconds > 0 ? null : () => _resend(),
                            child: Text(
                              _resendSeconds > 0
                                  ? 'Resend in ${_resendSeconds}s'
                                  : 'Resend OTP',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      ),
    );
  }
}
