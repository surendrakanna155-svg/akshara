class PlatformIntelligenceResponseDto {
  const PlatformIntelligenceResponseDto({
    required this.data,
  });

  final Map<String, dynamic> data;

  factory PlatformIntelligenceResponseDto.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    if (rawData is Map<String, dynamic>) {
      return PlatformIntelligenceResponseDto(data: rawData);
    }
    return const PlatformIntelligenceResponseDto(data: {});
  }
}
