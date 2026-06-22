import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../admin/admin_layout.dart';
import 'finance_models.dart';
import 'finance_mutations_provider.dart';
import 'finance_payments_provider.dart';
import 'finance_requests.dart';
import 'widgets/finance_module_scaffold.dart';

class FinanceQrPaymentScreen extends ConsumerStatefulWidget {
  const FinanceQrPaymentScreen({
    super.key,
    this.initialInvoiceId,
    this.initialAmount,
  });

  final String? initialInvoiceId;
  final String? initialAmount;

  @override
  ConsumerState<FinanceQrPaymentScreen> createState() =>
      _FinanceQrPaymentScreenState();
}

class _FinanceQrPaymentScreenState
    extends ConsumerState<FinanceQrPaymentScreen> {
  late final TextEditingController _invoiceController;
  late final TextEditingController _amountController;
  final TextEditingController _receiptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _invoiceController = TextEditingController(
      text: widget.initialInvoiceId ?? 'inv_1',
    );
    _amountController = TextEditingController(
      text: widget.initialAmount ?? '5000',
    );
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _amountController.dispose();
    _receiptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(qrPaymentSessionProvider);
    final createState = ref.watch(createQrPaymentSessionProvider);
    final confirmState = ref.watch(confirmQrPaymentSessionProvider);
    final activeSession = sessionAsync.valueOrNull ?? createState.valueOrNull;
    final isBusy = createState.isLoading || confirmState.isLoading;

    return FinanceModuleScaffold(
      screen: FinanceScreen.collections,
      showFilterBar: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('QR Payment', style: context.aksharaText.headlineSmall),
          const SizedBox(height: AksharaSpacing.s4),
          if (AdminLayout.useCardLayout(context))
            _buildForm(isBusy)
          else
            Row(
              children: [
                Expanded(child: _buildForm(isBusy)),
                const SizedBox(width: AksharaSpacing.s4),
                Expanded(child: _buildSessionCard(activeSession, isBusy)),
              ],
            ),
          if (AdminLayout.useCardLayout(context)) ...[
            const SizedBox(height: AksharaSpacing.s4),
            _buildSessionCard(activeSession, isBusy),
          ],
        ],
      ),
    );
  }

  Widget _buildForm(bool isBusy) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: QaTestKeys.financeQrInvoiceField,
              controller: _invoiceController,
              decoration: const InputDecoration(labelText: 'Invoice ID'),
            ),
            const SizedBox(height: AksharaSpacing.s3),
            TextField(
              key: QaTestKeys.financeQrAmountField,
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: AksharaSpacing.s4),
            FilledButton.icon(
              key: QaTestKeys.financeGenerateQrButton,
              onPressed: isBusy ? null : _generateQr,
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Generate QR'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(QrPaymentSession? session, bool isBusy) {
    if (session == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AksharaSpacing.s5),
          child: Text('Generate a QR to start UPI collection.'),
        ),
      );
    }
    final isPending = session.status == QrPaymentSessionStatus.pending;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Session ${session.id}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AksharaSpacing.s2),
            Text('Invoice: ${session.invoiceId}'),
            Text('Amount: ${session.amount}'),
            Text('Status: ${session.status.name}'),
            Text('Expires: ${session.expiresAt.toLocal()}'),
            if (session.receiptNumber != null)
              Text('Receipt: ${session.receiptNumber}'),
            const SizedBox(height: AksharaSpacing.s4),
            Center(
              child: QrImageView(
                data: session.upiPayload,
                version: QrVersions.auto,
                size: 220,
              ),
            ),
            const SizedBox(height: AksharaSpacing.s3),
            SelectableText(session.upiPayload),
            const SizedBox(height: AksharaSpacing.s4),
            TextField(
              key: QaTestKeys.financeQrReceiptField,
              controller: _receiptController,
              decoration: const InputDecoration(
                labelText: 'Receipt number (optional)',
              ),
            ),
            const SizedBox(height: AksharaSpacing.s3),
            FilledButton.icon(
              key: QaTestKeys.financeConfirmQrPaymentButton,
              onPressed:
                  (!isPending || isBusy) ? null : () => _confirm(session.id),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirm payment received'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateQr() async {
    final invoiceId = _invoiceController.text.trim();
    final amount = _amountController.text.trim();
    if (invoiceId.isEmpty || amount.isEmpty) return;

    final session =
        await ref.read(createQrPaymentSessionProvider.notifier).execute(
              CreateQrPaymentSessionRequest(
                invoiceId: invoiceId,
                amount: amount,
              ),
            );
    if (!mounted || session == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR session generated')),
    );
  }

  Future<void> _confirm(String sessionId) async {
    final confirmed =
        await ref.read(confirmQrPaymentSessionProvider.notifier).execute(
              sessionId: sessionId,
              request: ConfirmQrPaymentRequest(
                receiptNumber: _receiptController.text.trim().isEmpty
                    ? null
                    : _receiptController.text.trim(),
              ),
            );
    if (!mounted || confirmed == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.financeQrPaymentConfirmedSnackbar,
        content: Text(
          'QR payment confirmed (${confirmed.receiptNumber ?? confirmed.id})',
        ),
      ),
    );
  }
}
