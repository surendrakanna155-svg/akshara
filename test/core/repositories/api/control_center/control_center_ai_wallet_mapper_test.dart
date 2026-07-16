import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/core/repositories/api/control_center/dto/control_center_enum_codec.dart';
import 'package:akshara_erp/core/repositories/api/control_center/dto/control_center_responses_dto.dart';
import 'package:akshara_erp/core/repositories/api/control_center/mapper/control_center_mapper.dart';
import 'package:akshara_erp/features/platform/control_center/control_center_models.dart';

/// PRC-A Batch 3 — AI credit wallet DTO + mapper coverage. Mirrors the
/// `{ "data": <payload>, "error": null }` envelope the live `/ai-wallet` and
/// `/ai-wallet/grant` routes return (`ai_wallet_handlers.ts`).
void main() {
  const mapper = ControlCenterMapper();

  group('AiWalletResponseDto', () {
    test('parses the GET /ai-wallet payload, including a negative availableUnits', () {
      final dto = AiWalletResponseDto.fromJson({
        'data': {
          'balance': {
            'grantedUnits': 4580,
            'debitedUnits': 5120,
            'reservedUnits': 40,
            'availableUnits': -580,
            'lastTopUpUnits': 5000,
            'health': 'empty',
          },
          'entries': [
            {
              'id': 'AICR-101',
              'entryType': 'top_up',
              'units': 5000,
              'reason': 'Quarterly AI credit purchase',
              'actorId': 'plat_admin_1',
              'externalRef': 'PO-2026-0044',
              'createdAt': '2026-04-01T09:00:00.000Z',
            },
          ],
        },
        'error': null,
      });

      expect(dto.raw['balance'], isA<Map<String, dynamic>>());
      final balance = dto.raw['balance'] as Map<String, dynamic>;
      expect(balance['availableUnits'], -580);

      final mapped = mapper.toAiWallet(dto);
      expect(mapped.balance.availableUnits, -580);
      expect(mapped.balance.availableUnits, isNegative);
      expect(mapped.balance.grantedUnits, 4580);
      expect(mapped.balance.debitedUnits, 5120);
      expect(mapped.balance.reservedUnits, 40);
      expect(mapped.balance.lastTopUpUnits, 5000);
      expect(mapped.balance.health, AiWalletHealth.empty);
      expect(mapped.entries, hasLength(1));
    });

    for (final entry in {
      'healthy': AiWalletHealth.healthy,
      'low': AiWalletHealth.low,
      'empty': AiWalletHealth.empty,
    }.entries) {
      test('parses health value "${entry.key}"', () {
        final dto = AiWalletResponseDto.fromJson({
          'data': {
            'balance': {
              'grantedUnits': 1000,
              'debitedUnits': 100,
              'reservedUnits': 0,
              'availableUnits': 900,
              'lastTopUpUnits': 1000,
              'health': entry.key,
            },
            'entries': <Map<String, dynamic>>[],
          },
        });

        expect(
          ControlCenterEnumCodec.parseAiWalletHealth(entry.key),
          entry.value,
        );
        expect(mapper.toAiWallet(dto).balance.health, entry.value);
      });
    }

    test('defaults health to healthy for an unknown/missing value', () {
      expect(ControlCenterEnumCodec.parseAiWalletHealth(null), AiWalletHealth.healthy);
      expect(
        ControlCenterEnumCodec.parseAiWalletHealth('not_a_real_value'),
        AiWalletHealth.healthy,
      );
    });

    test('missing balance/entries default to zeroed values, not a throw', () {
      final dto = AiWalletResponseDto.fromJson({'data': <String, dynamic>{}});
      final mapped = mapper.toAiWallet(dto);
      expect(mapped.balance.grantedUnits, 0);
      expect(mapped.balance.availableUnits, 0);
      expect(mapped.balance.health, AiWalletHealth.healthy);
      expect(mapped.entries, isEmpty);
    });
  });

  group('ControlCenterMapper.toAiWallet — ledger entries', () {
    test('maps each entry with its signed units preserved', () {
      final dto = AiWalletResponseDto.fromJson({
        'data': {
          'balance': {
            'grantedUnits': 4580,
            'debitedUnits': 3120,
            'reservedUnits': 40,
            'availableUnits': 1420,
            'lastTopUpUnits': 5000,
            'health': 'healthy',
          },
          'entries': [
            {
              'id': 'AICR-101',
              'entryType': 'top_up',
              'units': 5000,
              'reason': 'Quarterly AI credit purchase',
              'actorId': 'plat_admin_1',
              'externalRef': 'PO-2026-0044',
              'createdAt': '2026-04-01T09:00:00.000Z',
            },
            {
              'id': 'AICR-108',
              'entryType': 'adjustment',
              'units': -120,
              'reason': 'Correction: duplicate AI call billed twice',
              'actorId': 'plat_admin_1',
              'externalRef': null,
              'createdAt': '2026-05-14T11:30:00.000Z',
            },
            {
              'id': 'AICR-112',
              'entryType': 'expiry',
              'units': -300,
              'reason': 'Unused promotional credits expired',
              'actorId': null,
              'externalRef': null,
              'createdAt': '2026-06-01T00:00:00.000Z',
            },
          ],
        },
      });

      final mapped = mapper.toAiWallet(dto);
      expect(mapped.entries, hasLength(3));

      final topUp = mapped.entries[0];
      expect(topUp.id, 'AICR-101');
      expect(topUp.entryType, 'top_up');
      expect(topUp.units, 5000);
      expect(topUp.units, isPositive);
      expect(topUp.actorId, 'plat_admin_1');
      expect(topUp.externalRef, 'PO-2026-0044');

      final adjustment = mapped.entries[1];
      expect(adjustment.entryType, 'adjustment');
      expect(adjustment.units, -120);
      expect(adjustment.units, isNegative);
      expect(adjustment.externalRef, isNull);

      final expiry = mapped.entries[2];
      expect(expiry.entryType, 'expiry');
      expect(expiry.units, -300);
      expect(expiry.units, isNegative);
      expect(expiry.actorId, isNull);
      expect(expiry.reason, 'Unused promotional credits expired');
    });
  });

  group('ControlCenterMapper.toAiWalletGrant', () {
    test('maps the POST /ai-wallet/grant balance payload', () {
      final dto = AiWalletGrantResponseDto.fromJson({
        'data': {
          'entry': {'id': 'AICR-113', 'entryType': 'top_up', 'units': 2000},
          'balance': {
            'grantedUnits': 6580,
            'debitedUnits': 3120,
            'reservedUnits': 40,
            'availableUnits': 3420,
            'lastTopUpUnits': 2000,
            'health': 'healthy',
          },
        },
      });

      final mapped = mapper.toAiWalletGrant(dto);
      expect(mapped.balance.grantedUnits, 6580);
      expect(mapped.balance.availableUnits, 3420);
      expect(mapped.balance.lastTopUpUnits, 2000);
      expect(mapped.balance.health, AiWalletHealth.healthy);
      // The grant response only echoes the single new entry, not the full
      // ledger — callers refresh getAiWallet separately for the entries list.
      expect(mapped.entries, isEmpty);
    });
  });
}
