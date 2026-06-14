class CreateGrowthCampaignRequest {
  const CreateGrowthCampaignRequest({
    required this.name,
    required this.channel,
    this.budgetInr,
    this.audience = 'all',
    this.scheduledAt,
  });

  final String name;
  final String channel;
  final double? budgetInr;
  final String audience;
  final String? scheduledAt;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'channel': channel,
      if (budgetInr != null) 'budgetInr': budgetInr,
      'audience': audience,
      if (scheduledAt != null && scheduledAt!.isNotEmpty)
        'scheduledAt': scheduledAt,
    };
  }
}

class UpdateGrowthCampaignRequest {
  const UpdateGrowthCampaignRequest({
    this.name,
    this.channel,
    this.status,
    this.budgetInr,
    this.audience,
    this.scheduledAt,
  });

  final String? name;
  final String? channel;
  final String? status;
  final double? budgetInr;
  final String? audience;
  final String? scheduledAt;

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (channel != null) 'channel': channel,
      if (status != null) 'status': status,
      if (budgetInr != null) 'budgetInr': budgetInr,
      if (audience != null) 'audience': audience,
      if (scheduledAt != null) 'scheduledAt': scheduledAt,
    };
  }
}
