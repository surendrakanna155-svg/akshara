import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/environment_provider.dart';
import '../../features/school_completion/school_branding_theme_provider.dart';
import '../../router/route_names.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'auth_models.dart';
import 'auth_provider.dart';

/// P-03 Login — phone OTP with production API or explicit testing mode.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const double _tabletBreakpoint = 768;
  static const double _maxFormWidth = 400;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;
  TestingLoginAccount? _selectedTestingAccount;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    final phone = _phoneController.text.trim();
    final demoAuth = ref.read(isDemoAuthEnabledProvider);
    final UserRole role;
    if (demoAuth) {
      role = _selectedTestingAccount?.role ?? ref.read(demoLoginRoleProvider);
    } else {
      role = UserRole.parent;
    }

    if (demoAuth && _selectedTestingAccount != null) {
      await ref
          .read(authProvider.notifier)
          .applyTestingAccount(_selectedTestingAccount!);
    }

    final sent = await ref.read(authProvider.notifier).sendOtp(phone, role);
    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);

    if (sent) {
      final roleQuery = demoAuth ? '&role=${role.name}' : '';
      context.go(
        '${RouteNames.otpVerification}?phone=$phone$roleQuery',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            demoAuth
                ? 'Enter a valid 10-digit mobile number'
                : 'Unable to send OTP. Use a registered demo-school phone number.',
          ),
        ),
      );
    }
  }

  void _selectTestingAccount(TestingLoginAccount account) {
    setState(() {
      _selectedTestingAccount = account;
      _phoneController.text = account.phone;
    });
    ref.read(authProvider.notifier).applyTestingAccount(account);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final demoAuth = ref.watch(isDemoAuthEnabledProvider);
    final schoolName = ref.watch(schoolDisplayNameProvider);
    final logoUrl = ref.watch(schoolLogoUrlProvider);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet =
                constraints.maxWidth >= LoginScreen._tabletBreakpoint;
            final horizontalPadding = isTablet
                ? AksharaSpacing.tabletMargin
                : AksharaSpacing.mobileMargin;

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: LoginScreen._maxFormWidth,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    AksharaSpacing.s8,
                    horizontalPadding,
                    AksharaSpacing.s6,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (logoUrl != null && logoUrl.startsWith('http'))
                          Image.network(logoUrl, height: 56)
                        else
                          Icon(
                            Icons.school_rounded,
                            size: 48,
                            color: colors.primary,
                          ),
                        const SizedBox(height: AksharaSpacing.s6),
                        if (schoolName.isNotEmpty)
                          Text(
                            schoolName,
                            style: text.titleMedium.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        const SizedBox(height: AksharaSpacing.s2),
                        Text(
                          'Welcome back',
                          style: text.headlineSmall.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AksharaSpacing.s2),
                        Text(
                          demoAuth
                              ? 'Testing mode — choose a demo account, then sign in with OTP 123456.'
                              : 'Enter your registered mobile number. OTP is verified by the staging server.',
                          style: text.bodyMedium.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        if (demoAuth) ...[
                          const SizedBox(height: AksharaSpacing.s6),
                          Text(
                            'Testing accounts',
                            style: text.labelLarge,
                          ),
                          const SizedBox(height: AksharaSpacing.s2),
                          Wrap(
                            spacing: AksharaSpacing.s2,
                            runSpacing: AksharaSpacing.s2,
                            children: [
                              for (final account in kTestingLoginAccounts)
                                ChoiceChip(
                                  label: Text(account.label),
                                  selected:
                                      _selectedTestingAccount?.phone ==
                                          account.phone,
                                  onSelected: (_) =>
                                      _selectTestingAccount(account),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: AksharaSpacing.s8),
                        Text(
                          'Mobile number',
                          style: text.labelLarge,
                        ),
                        const SizedBox(height: AksharaSpacing.s2),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration: InputDecoration(
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(
                                left: AksharaSpacing.s4,
                                right: AksharaSpacing.s2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '+91',
                                    style: text.bodyLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: AksharaSpacing.s2),
                                  Container(
                                    width: 1,
                                    height: 24,
                                    color: colors.outlineVariant,
                                  ),
                                ],
                              ),
                            ),
                            hintText: demoAuth ? '9000100001' : '9876543210',
                            border: OutlineInputBorder(
                              borderRadius: AksharaRadius.inputBorder,
                            ),
                          ),
                          validator: (value) {
                            final digits =
                                (value ?? '').replaceAll(RegExp(r'\D'), '');
                            if (digits.length != 10) {
                              return 'Enter a valid 10-digit number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AksharaSpacing.s6),
                        FilledButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: AksharaRadius.button,
                            ),
                          ),
                          child: _isSubmitting
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.onPrimary,
                                  ),
                                )
                              : const Text('Continue'),
                        ),
                        if (demoAuth) ...[
                          const SizedBox(height: AksharaSpacing.s4),
                          Text(
                            'Testing OTP: $kMockValidOtp only',
                            style: text.bodySmall.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: AksharaSpacing.s4),
                        TextButton.icon(
                          onPressed: () => context.go(RouteNames.staffLogin),
                          icon: const Icon(Icons.badge_outlined),
                          label: const Text('Staff ERP portal'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
