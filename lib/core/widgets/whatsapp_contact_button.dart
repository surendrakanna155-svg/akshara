import 'package:flutter/material.dart';

import '../utils/whatsapp_launcher.dart';

/// Visual variants for [WhatsAppContactButton].
enum WhatsAppButtonStyle { outlined, text, icon }

/// Reusable "contact on WhatsApp" affordance used across roles (teacher→parent,
/// principal/HR→staff, parent→class-teacher, …).
///
/// Encapsulates the whole deep-link flow once — validate the number, open
/// WhatsApp prefilled with [message], and surface a SnackBar when the number is
/// missing or WhatsApp can't be opened — so every caller behaves identically.
///
/// Renders nothing when [phone] has no dialable digits (no dead button). This is
/// a Phase-1 deep link (no Meta Business API): the user reviews and sends the
/// message themselves.
class WhatsAppContactButton extends StatelessWidget {
  const WhatsAppContactButton({
    super.key,
    required this.phone,
    required this.message,
    this.label = 'WhatsApp',
    this.style = WhatsAppButtonStyle.outlined,
    this.unavailableMessage = 'Contact number is unavailable.',
    this.onSent,
  });

  /// The contact's phone (any format; 10-digit national numbers are auto-prefixed
  /// with the default country code by [WhatsAppLauncher]).
  final String? phone;

  /// Prefilled message text the user can review before sending.
  final String message;

  final String label;
  final WhatsAppButtonStyle style;
  final String unavailableMessage;

  /// Fired once WhatsApp has been opened successfully — lets a caller record the
  /// contact on a timeline (e.g. admissions auto-logs a WhatsApp note). It is a
  /// best-effort side effect: the user still reviews and sends the message
  /// themselves, so this signals "reached out via WhatsApp", not "delivered".
  final Future<void> Function()? onSent;

  bool get _hasNumber => WhatsAppLauncher.resolvePhoneDigits(phone ?? '') != null;

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final digits = WhatsAppLauncher.resolvePhoneDigits(phone ?? '');
    if (digits == null) {
      messenger.showSnackBar(SnackBar(content: Text(unavailableMessage)));
      return;
    }
    final opened =
        await WhatsAppLauncher.openChat(phoneE164: digits, message: message);
    if (!opened) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp on this device.')),
      );
      return;
    }
    // Best-effort timeline log after a successful open (ADM-2).
    await onSent?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Hide entirely when there is no usable number — never show a dead control.
    if (!_hasNumber) return const SizedBox.shrink();

    const icon = Icon(Icons.chat_outlined, size: 18);
    switch (style) {
      case WhatsAppButtonStyle.icon:
        return IconButton(
          tooltip: label,
          icon: icon,
          onPressed: () => _open(context),
        );
      case WhatsAppButtonStyle.text:
        return TextButton.icon(
          onPressed: () => _open(context),
          icon: icon,
          label: Text(label),
        );
      case WhatsAppButtonStyle.outlined:
        return OutlinedButton.icon(
          onPressed: () => _open(context),
          icon: icon,
          label: Text(label),
        );
    }
  }
}
