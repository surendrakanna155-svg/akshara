import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../auth_models.dart';
import '../auth_provider.dart';
import 'staff_login_provider.dart';

/// Staff OTP verification step.
class StaffOtpScreen extends ConsumerStatefulWidget {
  const StaffOtpScreen({
    super.key,
    required this.identifier,
    required this.identifierType,
  });

  final String identifier;
  final StaffLoginIdentifierType identifierType;

  @override
  ConsumerState<StaffOtpScreen> createState() => _StaffOtpScreenState();
}

class _StaffOtpScreenState extends ConsumerState<StaffOtpScreen> {
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
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  Future<void> _verify() async {
    setState(() => _isVerifying = true);
    final result = await ref
        .read(staffLoginProvider.notifier)
        .verifyOtp(_otpController.text.trim());
    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (result != null) {
      await ref.read(authProvider.notifier).completeStaffLogin(result);
      if (!mounted) return;
      context.go(homeRouteForRole(UserRole.staff));
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final loginState = ref.watch(staffLoginProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          ref.read(staffLoginProvider.notifier).reset();
          context.go(RouteNames.staffLogin);
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Verify OTP'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // A11y-P2: without a label this icon-only button announces as just
          // "button". The tooltip becomes the accessible name.
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () {
            ref.read(staffLoginProvider.notifier).reset();
            context.go(RouteNames.staffLogin);
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the OTP sent to',
                style: text.bodyLarge,
              ),
              const SizedBox(height: AksharaSpacing.s1),
              Text(
                widget.identifier,
                style: text.titleMedium.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AksharaSpacing.s6),
              if (loginState.errorMessage != null)
                AksharaErrorState(
                  message: loginState.errorMessage!,
                  onRetry: _verify,
                ),
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  labelText: '6-digit OTP',
                  hintText: '••••••',
                  border: OutlineInputBorder(
                    borderRadius: AksharaRadius.inputBorder,
                  ),
                ),
              ),
              const SizedBox(height: AksharaSpacing.s4),
              FilledButton(
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
                    : const Text('Verify & sign in'),
              ),
              const SizedBox(height: AksharaSpacing.s3),
              TextButton(
                onPressed: _resendSeconds > 0
                    ? null
                    : () async {
                        await ref
                            .read(staffLoginProvider.notifier)
                            .sendOtp(widget.identifier);
                        _startResendTimer();
                      },
                child: Text(
                  _resendSeconds > 0
                      ? 'Resend OTP in $_resendSeconds s'
                      : 'Resend OTP',
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
