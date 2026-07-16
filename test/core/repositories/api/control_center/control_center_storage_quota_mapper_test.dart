import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/core/repositories/api/control_center/dto/control_center_enum_codec.dart';
import 'package:akshara_erp/core/repositories/api/control_center/dto/control_center_responses_dto.dart';
import 'package:akshara_erp/core/repositories/api/control_center/mapper/control_center_mapper.dart';
import 'package:akshara_erp/features/platform/control_center/control_center_models.dart';

/// PRC-A Batch 4 — storage quota DTO + mapper coverage. Mirrors the
/// `{ "data": <payload>, "error": null }` envelope the live `/storage/quota`
/// route returns (`storage_quota_handlers.ts`).
void main() {
  const mapper = ControlCenterMapper();

  group('StorageQuotaResponseDto', () {
    test('parses a capped plan payload', () {
      final dto = StorageQuotaResponseDto.fromJson({
        'data': {
          'planName': 'Standard',
          'usedBytes': 2254857830,
          'limitBytes': 5368709120,
          'availableBytes': 3113851290,
          'health': 'healthy',
          'enforced': false,
        },
        'error': null,
      });

      final mapped = mapper.toStorageQuota(dto);
      expect(mapped.planName, 'Standard');
      expect(mapped.usedBytes, 2254857830);
      expect(mapped.limitBytes, 5368709120);
      expect(mapped.availableBytes, 3113851290);
      expect(mapped.health, StorageQuotaHealth.healthy);
      expect(mapped.enforced, isFalse);
    });

    test('parses an unlimited plan — limitBytes and availableBytes are null', () {
      final dto = StorageQuotaResponseDto.fromJson({
        'data': {
          'planName': 'Enterprise',
          'usedBytes': 987654321,
          'limitBytes': null,
          'availableBytes': null,
          'health': 'unlimited',
          'enforced': false,
        },
      });

      final mapped = mapper.toStorageQuota(dto);
      expect(mapped.limitBytes, isNull);
      expect(mapped.availableBytes, isNull);
      expect(mapped.health, StorageQuotaHealth.unlimited);
      expect(mapped.usedBytes, 987654321);
    });

    test('parses enforced true', () {
      final dto = StorageQuotaResponseDto.fromJson({
        'data': {
          'planName': 'Standard',
          'usedBytes': 100,
          'limitBytes': 1000,
          'availableBytes': 900,
          'health': 'healthy',
          'enforced': true,
        },
      });

      expect(mapper.toStorageQuota(dto).enforced, isTrue);
    });

    for (final entry in {
      'unlimited': StorageQuotaHealth.unlimited,
      'healthy': StorageQuotaHealth.healthy,
      'low': StorageQuotaHealth.low,
      'full': StorageQuotaHealth.full,
    }.entries) {
      test('parses health value "${entry.key}"', () {
        final dto = StorageQuotaResponseDto.fromJson({
          'data': {
            'planName': 'Standard',
            'usedBytes': 100,
            'limitBytes': 1000,
            'availableBytes': 900,
            'health': entry.key,
            'enforced': false,
          },
        });

        expect(
          ControlCenterEnumCodec.parseStorageQuotaHealth(entry.key),
          entry.value,
        );
        expect(mapper.toStorageQuota(dto).health, entry.value);
      });
    }

    test('defaults health to healthy for an unknown/missing value', () {
      expect(ControlCenterEnumCodec.parseStorageQuotaHealth(null), StorageQuotaHealth.healthy);
      expect(
        ControlCenterEnumCodec.parseStorageQuotaHealth('not_a_real_value'),
        StorageQuotaHealth.healthy,
      );
    });

    test('defaults enforced to false and usedBytes to 0 when missing, not a throw', () {
      final dto = StorageQuotaResponseDto.fromJson({'data': <String, dynamic>{}});
      final mapped = mapper.toStorageQuota(dto);
      expect(mapped.planName, '');
      expect(mapped.usedBytes, 0);
      expect(mapped.limitBytes, isNull);
      expect(mapped.availableBytes, isNull);
      expect(mapped.health, StorageQuotaHealth.healthy);
      expect(mapped.enforced, isFalse);
    });

    test('parses large byte counts without precision loss', () {
      final dto = StorageQuotaResponseDto.fromJson({
        'data': {
          'planName': 'Enterprise',
          'usedBytes': 987654321098,
          'limitBytes': 1099511627776, // 1 TiB
          'availableBytes': 111857306678,
          'health': 'low',
          'enforced': true,
        },
      });

      final mapped = mapper.toStorageQuota(dto);
      expect(mapped.usedBytes, 987654321098);
      expect(mapped.limitBytes, 1099511627776);
      expect(mapped.availableBytes, 111857306678);
    });
  });
}
