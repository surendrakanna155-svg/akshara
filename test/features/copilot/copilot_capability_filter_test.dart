import 'package:akshara_erp/core/school_config/school_configuration_models.dart';
import 'package:akshara_erp/features/copilot/copilot_capability_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blocks transport topic when transport capability disabled', () {
    const capabilities = SchoolCapabilities(transport: false);
    final message = CopilotCapabilityFilter.disabledTopicMessage(
      userMessage: 'Show bus route utilization',
      capabilities: capabilities,
      module: 'finance',
    );
    expect(message, isNotNull);
    expect(message, contains('transport'));
  });

  test('allows finance topics when transport disabled', () {
    const capabilities = SchoolCapabilities(transport: false);
    final message = CopilotCapabilityFilter.disabledTopicMessage(
      userMessage: 'Summarize fee collection',
      capabilities: capabilities,
      module: 'finance',
    );
    expect(message, isNull);
  });
}
