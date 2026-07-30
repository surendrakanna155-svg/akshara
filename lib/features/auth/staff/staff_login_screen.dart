import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/environment_provider.dart';
import '../../../core/repositories/repository_config.dart';
import '../../../core/security/erp_role.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'staff_login_provider.dart';
import '../../../theme/breakpoints.dart';

/// Production staff ERP login — email or mobile with OTP.
class StaffLoginScreen extends ConsumerStatefulWidget {
  const StaffLoginScreen({super.key});

  static const double _tabletBreakpoint = AksharaBreakpoints.tabletMinWidth;
  static const double _maxFormWidth = 420;

  @override
  ConsumerState<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends ConsumerState<StaffLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final sent = await ref
        .read(staffLoginProvider.notifier)
        .sendOtp(_identifierController.text.trim());
    if (!mounted) return;

    if (sent) {
      final state = ref.read(staffLoginProvider);
      context.go(
        '${RouteNames.staffOtp}?id=${Uri.encodeComponent(state.identifier)}&type=${state.identifierType.name}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final loginState = ref.watch(staffLoginProvider);
    final authApiActive =
        ref.watch(enableApiModeProvider) && ref.watch(authApiEnabledProvider);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Staff Portal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // A11y-P2: without a label this icon-only button announces as just
          // "button". The tooltip becomes the accessible name.
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.go(RouteNames.login),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet =
                constraints.maxWidth >= StaffLoginScreen._tabletBreakpoint;
            final horizontalPadding = isTablet
                ? AksharaSpacing.tabletMargin
                : AksharaSpacing.mobileMargin;

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: StaffLoginScreen._maxFormWidth,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    AksharaSpacing.s6,
                    horizontalPadding,
                    AksharaSpacing.s6,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.badge_outlined,
                          size: 48,
                          color: colors.primary,
                        ),
                        const SizedBox(height: AksharaSpacing.s4),
                        Text(
                          'Staff sign in',
                          style: text.headlineSmall.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AksharaSpacing.s2),
                        Text(
                          'Sign in with your work email or mobile number.',
                          style: text.bodyMedium.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        if (loginState.errorMessage != null) ...[
                          const SizedBox(height: AksharaSpacing.s4),
                          AksharaErrorState(
                            message: loginState.errorMessage!,
                            onRetry: () => ref
                                .read(staffLoginProvider.notifier)
                                .reset(),
                            retryLabel: 'Dismiss',
                          ),
                        ],
                        const SizedBox(height: AksharaSpacing.s6),
                        SegmentedButton<StaffLoginIdentifierType>(
                          segments: const [
                            ButtonSegment(
                              value: StaffLoginIdentifierType.email,
                              label: Text('Email'),
                              icon: Icon(Icons.email_outlined, size: 18),
                            ),
                            ButtonSegment(
                              value: StaffLoginIdentifierType.mobile,
                              label: Text('Mobile'),
                              icon: Icon(Icons.phone_outlined, size: 18),
                            ),
                          ],
                          selected: {loginState.identifierType},
                          onSelectionChanged: (selection) {
                            ref
                                .read(staffLoginProvider.notifier)
                                .setIdentifierType(selection.first);
                          },
                        ),
                        const SizedBox(height: AksharaSpacing.s4),
                        TextFormField(
                          controller: _identifierController,
                          keyboardType: loginState.identifierType ==
                                  StaffLoginIdentifierType.mobile
                              ? TextInputType.phone
                              : TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          inputFormatters: loginState.identifierType ==
                                  StaffLoginIdentifierType.mobile
                              ? [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ]
                              : null,
                          decoration: InputDecoration(
                            labelText: loginState.identifierType ==
                                    StaffLoginIdentifierType.mobile
                                ? 'Mobile number'
                                : 'Work email',
                            hintText: loginState.identifierType ==
                                    StaffLoginIdentifierType.mobile
                                ? '9876543210'
                                : 'name@school.edu',
                            border: OutlineInputBorder(
                              borderRadius: AksharaRadius.inputBorder,
                            ),
                          ),
                          validator: (value) {
                            final raw = (value ?? '').trim();
                            if (loginState.identifierType ==
                                StaffLoginIdentifierType.mobile) {
                              if (raw.replaceAll(RegExp(r'\D'), '').length !=
                                  10) {
                                return 'Enter a valid 10-digit number';
                              }
                            } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                                .hasMatch(raw)) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        if (!authApiActive) ...[
                          const SizedBox(height: AksharaSpacing.s4),
                          Text('ERP role (demo)', style: text.labelLarge),
                          const SizedBox(height: AksharaSpacing.s2),
                          DropdownButtonFormField<ErpRole>(
                            initialValue: loginState.selectedRole,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: AksharaRadius.inputBorder,
                              ),
                            ),
                            // The role list is data-driven, so a longer label
                            // (e.g. "Health / Infirmary Staff") must reflow, not
                            // overflow the row.
                            isExpanded: true,
                            items: [
                              // JOURNEY-002: `supportedValues`, not `values` —
                              // the fail-closed sentinel is not a role anyone can
                              // be assigned, so it must never be offered.
                              for (final role in ErpRole.supportedValues)
                                DropdownMenuItem(
                                  value: role,
                                  child: Text(
                                    role.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (role) {
                              if (role != null) {
                                ref
                                    .read(staffLoginProvider.notifier)
                                    .setSelectedRole(role);
                              }
                            },
                          ),
                        ],
                        const SizedBox(height: AksharaSpacing.s3),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Remember session'),
                          subtitle: const Text(
                            'Stay signed in on this device',
                          ),
                          value: loginState.rememberSession,
                          onChanged: (value) => ref
                              .read(staffLoginProvider.notifier)
                              .setRememberSession(value),
                        ),
                        const SizedBox(height: AksharaSpacing.s4),
                        FilledButton(
                          onPressed: loginState.isLoading ? null : _submit,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: AksharaRadius.button,
                            ),
                          ),
                          child: loginState.isLoading
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.onPrimary,
                                  ),
                                )
                              : const Text('Send OTP'),
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
