import 'package:akshara_erp/core/repositories/api/support/dto/support_dtos.dart';
import 'package:akshara_erp/core/repositories/api/support/mapper/support_mapper.dart';
import 'package:akshara_erp/features/support/domain/support_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = SupportMapper();

  test('toDetail maps snake_case wire → domain and parses enums', () {
    final dto = SupportIncidentDetailDto.fromJson({
      'incident': {
        'id': 'i1',
        'public_ref': 'SUP-ABCD1234',
        'title': 'Cannot open marks',
        'description': 'nothing happens',
        'category': 'permission_rbac',
        'status': 'in_progress',
        'severity': 'sev2',
        'reporter_role': 'teacher',
        'module_key': 'sis',
        'created_at': '2026-07-20T10:00:00Z',
        'updated_at': '2026-07-20T10:05:00Z',
      },
      'events': [
        {'event_type': 'created', 'created_at': '2026-07-20T10:00:00Z'},
      ],
      'messages': [
        {
          'id': 'm1',
          'sender_kind': 'support',
          'visibility': 'school_visible',
          'body': 'looking into it',
          'created_at': '2026-07-20T10:02:00Z',
        },
        {
          'id': 'm2',
          'sender_kind': 'support',
          'visibility': 'internal_note',
          'body': 'internal only',
          'created_at': '2026-07-20T10:03:00Z',
        },
      ],
      'attachments': [
        {
          'id': 'a1',
          'kind': 'screenshot',
          'file_name': 's.png',
          'content_type': 'image/png',
          'size_bytes': 123,
          'download_url': 'https://x/s.png',
          'created_at': '2026-07-20T10:01:00Z',
        },
      ],
    });

    final detail = mapper.toDetail(dto);

    expect(detail.incident.publicRef, 'SUP-ABCD1234');
    expect(detail.incident.status, SupportStatus.inProgress);
    expect(detail.incident.severity, SupportSeverity.sev2);
    expect(detail.incident.moduleKey, 'sis');
    expect(detail.events.single.eventType, 'created');
    expect(detail.attachments.single.isImage, true);
    expect(detail.attachments.single.downloadUrl, 'https://x/s.png');

    // Both messages are present, but an internal note is never reporter-visible.
    expect(detail.messages.length, 2);
    expect(detail.visibleMessages.length, 1);
    expect(detail.visibleMessages.single.body, 'looking into it');
  });

  test('unknown enum wire values fall back safely', () {
    expect(SupportStatus.fromWire('gibberish'), SupportStatus.newIncident);
    expect(SupportSeverity.fromWire(null), SupportSeverity.sev3);
    expect(AttachmentKind.fromWire('nope'), AttachmentKind.screenshot);
  });

  test('formatSupportCategory humanizes a slug', () {
    expect(formatSupportCategory('permission_rbac'), 'Permission Rbac');
    expect(formatSupportCategory(null), 'Unknown');
  });
}
