import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/repositories/repository_providers.dart';
import '../../../../core/tenant/tenant_provider.dart';
import '../../../../core/testing/qa_test_keys.dart';
import '../../../../router/route_names.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/spacing.dart';
import '../../admissions_models.dart';

/// Result of the create-lead dialog: the entered fields, ready to build a
/// `CreateLeadRequest`. Null when the operator cancels.
class CreateLeadDialogResult {
  const CreateLeadDialogResult({
    required this.parentName,
    required this.studentName,
    required this.classLabel,
    required this.phone,
  });

  final String parentName;
  final String studentName;
  final String classLabel;
  final String phone;
}

/// ADM-D2: create-lead dialog with a warn-only duplicate-phone check. On phone
/// blur it queries `GET /admissions/leads/check-duplicate` and, if an existing
/// lead shares the number, shows a warning banner plus an "open existing"
/// affordance. The check never blocks creation (warn-only).
class AdmissionsCreateLeadDialog extends ConsumerStatefulWidget {
  const AdmissionsCreateLeadDialog({super.key});

  @override
  ConsumerState<AdmissionsCreateLeadDialog> createState() =>
      _AdmissionsCreateLeadDialogState();
}

class _AdmissionsCreateLeadDialogState
    extends ConsumerState<AdmissionsCreateLeadDialog> {
  final _parentController = TextEditingController();
  final _studentController = TextEditingController();
  final _classController = TextEditingController(text: '5');
  final _phoneController = TextEditingController();
  final _phoneFocus = FocusNode();

  DuplicateLeadCheckResult _duplicate = DuplicateLeadCheckResult.empty;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(_onPhoneFocusChange);
  }

  @override
  void dispose() {
    _phoneFocus.removeListener(_onPhoneFocusChange);
    _phoneFocus.dispose();
    _parentController.dispose();
    _studentController.dispose();
    _classController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onPhoneFocusChange() {
    if (!_phoneFocus.hasFocus) {
      _runDuplicateCheck();
    }
  }

  Future<void> _runDuplicateCheck() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _duplicate = DuplicateLeadCheckResult.empty);
      return;
    }
    setState(() => _checking = true);
    try {
      final result =
          await ref.read(admissionsRepositoryProvider).checkDuplicateByPhone(
                query: ref.read(repositoryQueryProvider),
                phone: phone,
              );
      if (!mounted) return;
      setState(() => _duplicate = result);
    } catch (_) {
      // Warn-only: a failed check must never block lead creation.
      if (!mounted) return;
      setState(() => _duplicate = DuplicateLeadCheckResult.empty);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _openExisting(String leadId) {
    Navigator.of(context).pop();
    context.push(RouteNames.admissionsLeadDetail(leadId));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New lead'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: QaTestKeys.admissionsLeadParentNameField,
              controller: _parentController,
              decoration: const InputDecoration(labelText: 'Parent name'),
            ),
            TextField(
              key: QaTestKeys.admissionsLeadStudentNameField,
              controller: _studentController,
              decoration: const InputDecoration(labelText: 'Student name'),
            ),
            TextField(
              key: QaTestKeys.admissionsLeadClassField,
              controller: _classController,
              decoration: const InputDecoration(labelText: 'Class'),
            ),
            TextField(
              key: QaTestKeys.admissionsLeadPhoneField,
              controller: _phoneController,
              focusNode: _phoneFocus,
              decoration: InputDecoration(
                labelText: 'Phone',
                suffixIcon: _checking
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              keyboardType: TextInputType.phone,
              onEditingComplete: () {
                _phoneFocus.unfocus();
                _runDuplicateCheck();
              },
            ),
            if (_duplicate.hasDuplicate) ...[
              const SizedBox(height: AksharaSpacing.s3),
              _DuplicateWarning(
                matches: _duplicate.matches,
                onOpenExisting: _openExisting,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.admissionsLeadDialogCreateButton,
          onPressed: () => Navigator.of(context).pop(
            CreateLeadDialogResult(
              parentName: _parentController.text.trim(),
              studentName: _studentController.text.trim(),
              classLabel: _classController.text.trim(),
              phone: _phoneController.text.trim(),
            ),
          ),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _DuplicateWarning extends StatelessWidget {
  const _DuplicateWarning({
    required this.matches,
    required this.onOpenExisting,
  });

  final List<DuplicateLeadMatch> matches;
  final void Function(String leadId) onOpenExisting;

  @override
  Widget build(BuildContext context) {
    final first = matches.first;
    return Column(
      key: QaTestKeys.admissionsDuplicateWarningBanner,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AksharaWarningBanner(
          message: matches.length == 1
              ? 'A lead with this phone already exists: '
                  '${first.studentName} (${first.stage.label}).'
              : '${matches.length} leads already share this phone number.',
          compactMessage: true,
          semanticLabel: 'Duplicate phone warning',
        ),
        const SizedBox(height: AksharaSpacing.s2),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: QaTestKeys.admissionsDuplicateOpenExistingButton,
            onPressed: () => onOpenExisting(first.leadId),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text('Open ${first.studentName}'),
          ),
        ),
      ],
    );
  }
}
