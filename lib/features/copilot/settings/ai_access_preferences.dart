import 'ai_access_mode.dart';

/// Per-account AI access preferences (INTEL-05).
class AiAccessPreferences {
  const AiAccessPreferences({
    this.mode = AiAccessMode.auto,
    this.floatingBubbleEnabled = false,
  });

  final AiAccessMode mode;
  final bool floatingBubbleEnabled;

  AiAccessPreferences copyWith({
    AiAccessMode? mode,
    bool? floatingBubbleEnabled,
  }) {
    return AiAccessPreferences(
      mode: mode ?? this.mode,
      floatingBubbleEnabled: floatingBubbleEnabled ?? this.floatingBubbleEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.storageKey,
        'floatingBubbleEnabled': floatingBubbleEnabled,
      };

  factory AiAccessPreferences.fromJson(Map<String, dynamic> json) {
    return AiAccessPreferences(
      mode: AiAccessMode.fromStorageKey(json['mode'] as String?) ??
          AiAccessMode.auto,
      floatingBubbleEnabled: json['floatingBubbleEnabled'] as bool? ?? false,
    );
  }
}
