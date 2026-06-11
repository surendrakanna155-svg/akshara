import '../../../../../features/school_completion/school_completion_models.dart';

class SchoolCompletionPhase15Mapper {
  const SchoolCompletionPhase15Mapper();

  CommunicationAnalyticsSummary toCommunicationAnalyticsSummary(Map<String, dynamic> json) {
    Map<String, dynamic> map(dynamic v) => v is Map<String, dynamic> ? v : const {};

    return CommunicationAnalyticsSummary(
      campaigns: toCampaignAnalytics(map(json['campaigns'])),
      delivery: toAnalyticsDelivery(map(json['delivery'])),
      effectiveness: toCommunicationEffectiveness(map(json['effectiveness'])),
      parentEngagement: toParentEngagement(map(json['parentEngagement'] ?? json['parent_engagement'])),
      parentAdoption: toParentAdoption(map(json['parentAdoption'] ?? json['parent_adoption'])),
    );
  }

  CampaignAnalytics toCampaignAnalytics(Map<String, dynamic> json) {
    final campaignsRaw = json['campaigns'];
    return CampaignAnalytics(
      totalCampaigns: json['totalCampaigns'] as int? ?? json['total_campaigns'] as int? ?? 0,
      activeCampaigns: json['activeCampaigns'] as int? ?? json['active_campaigns'] as int? ?? 0,
      aggregateDeliveryRate:
          json['aggregateDeliveryRate'] as int? ?? json['aggregate_delivery_rate'] as int? ?? 0,
      aggregateOpenRate:
          json['aggregateOpenRate'] as int? ?? json['aggregate_open_rate'] as int? ?? 0,
      aggregateResponseRate:
          json['aggregateResponseRate'] as int? ?? json['aggregate_response_rate'] as int? ?? 0,
      campaigns: campaignsRaw is List
          ? campaignsRaw.map((e) => toCampaignSummary(Map<String, dynamic>.from(e as Map))).toList()
          : const [],
    );
  }

  CampaignSummary toCampaignSummary(Map<String, dynamic> json) => CampaignSummary(
        id: json['id'] as String? ?? '',
        campaignCode: json['campaignCode'] as String? ?? json['campaign_code'] as String? ?? '',
        campaignName: json['campaignName'] as String? ?? json['campaign_name'] as String? ?? '',
        channel: json['channel'] as String? ?? '',
        templateCode: json['templateCode'] as String? ?? json['template_code'] as String?,
        status: json['status'] as String? ?? '',
        sentCount: json['sentCount'] as int? ?? json['sent_count'] as int? ?? 0,
        deliveredCount: json['deliveredCount'] as int? ?? json['delivered_count'] as int? ?? 0,
        failedCount: json['failedCount'] as int? ?? json['failed_count'] as int? ?? 0,
        openRate: json['openRate'] as int? ?? json['open_rate'] as int? ?? 0,
        responseRate: json['responseRate'] as int? ?? json['response_rate'] as int? ?? 0,
      );

  AnalyticsDeliverySnapshot toAnalyticsDelivery(Map<String, dynamic> json) {
    final byChannelRaw = json['byChannel'] ?? json['by_channel'];
    final byChannel = <String, DeliveryChannelStats>{};
    if (byChannelRaw is Map) {
      for (final entry in byChannelRaw.entries) {
        final v = entry.value as Map;
        byChannel[entry.key.toString()] = DeliveryChannelStats(
          sent: v['sent'] as int? ?? 0,
          failed: v['failed'] as int? ?? 0,
          pending: v['pending'] as int? ?? 0,
        );
      }
    }
    final trendRaw = json['trend'];
    return AnalyticsDeliverySnapshot(
      totalSent: json['totalSent'] as int? ?? json['total_sent'] as int? ?? 0,
      totalFailed: json['totalFailed'] as int? ?? json['total_failed'] as int? ?? 0,
      totalPending: json['totalPending'] as int? ?? json['total_pending'] as int? ?? 0,
      deliveryRate: json['deliveryRate'] as int? ?? json['delivery_rate'] as int? ?? 0,
      byChannel: byChannel,
      last7DaysSent: json['last7DaysSent'] as int? ?? json['last_7_days_sent'] as int? ?? 0,
      last7DaysFailed: json['last7DaysFailed'] as int? ?? json['last_7_days_failed'] as int? ?? 0,
      trend: trendRaw is List
          ? trendRaw
              .map((e) {
                final m = e as Map;
                return AnalyticsDeliveryTrendPoint(
                  date: m['date'] as String? ?? '',
                  sent: m['sent'] as int? ?? 0,
                  failed: m['failed'] as int? ?? 0,
                );
              })
              .toList()
          : const [],
    );
  }

  CommunicationEffectiveness toCommunicationEffectiveness(Map<String, dynamic> json) {
    final templatesRaw = json['topTemplates'] ?? json['top_templates'];
    final channelRaw = json['channelEffectiveness'] ?? json['channel_effectiveness'];
    final channelEffectiveness = <String, ChannelEffectiveness>{};
    if (channelRaw is Map) {
      for (final entry in channelRaw.entries) {
        final v = entry.value as Map;
        channelEffectiveness[entry.key.toString()] = ChannelEffectiveness(
          sent: v['sent'] as int? ?? 0,
          openRate: v['openRate'] as int? ?? v['open_rate'] as int? ?? 0,
          responseRate: v['responseRate'] as int? ?? v['response_rate'] as int? ?? 0,
        );
      }
    }
    return CommunicationEffectiveness(
      effectivenessScore:
          json['effectivenessScore'] as int? ?? json['effectiveness_score'] as int? ?? 0,
      openRate: json['openRate'] as int? ?? json['open_rate'] as int? ?? 0,
      responseRate: json['responseRate'] as int? ?? json['response_rate'] as int? ?? 0,
      topTemplates: templatesRaw is List
          ? templatesRaw
              .map((e) {
                final m = e as Map;
                return TemplateEffectiveness(
                  templateCode: m['templateCode'] as String? ?? m['template_code'] as String? ?? '',
                  sent: m['sent'] as int? ?? 0,
                  openRate: m['openRate'] as int? ?? m['open_rate'] as int? ?? 0,
                );
              })
              .toList()
          : const [],
      channelEffectiveness: channelEffectiveness,
    );
  }

  ParentEngagementAnalytics toParentEngagement(Map<String, dynamic> json) {
    final topRaw = json['topEngagedParents'] ?? json['top_engaged_parents'];
    final trendRaw = json['engagementTrend'] ?? json['engagement_trend'];
    return ParentEngagementAnalytics(
      averageEngagementScore:
          json['averageEngagementScore'] as int? ?? json['average_engagement_score'] as int? ?? 0,
      activeParents30d:
          json['activeParents30d'] as int? ?? json['active_parents_30d'] as int? ?? 0,
      lowEngagementParents:
          json['lowEngagementParents'] as int? ?? json['low_engagement_parents'] as int? ?? 0,
      topEngagedParents: topRaw is List
          ? topRaw
              .map((e) {
                final m = e as Map;
                return ParentEngagementEntry(
                  parentUserId: m['parentUserId'] as String? ?? m['parent_user_id'] as String? ?? '',
                  engagementScore: m['engagementScore'] as int? ?? m['engagement_score'] as int? ?? 0,
                  messagesRead30d:
                      m['messagesRead30d'] as int? ?? m['messages_read_30d'] as int? ?? 0,
                  appSessions30d: m['appSessions30d'] as int? ?? m['app_sessions_30d'] as int? ?? 0,
                  lastActiveAt: m['lastActiveAt'] as String? ?? m['last_active_at'] as String?,
                );
              })
              .toList()
          : const [],
      engagementTrend: trendRaw is List
          ? trendRaw
              .map((e) {
                final m = e as Map;
                return EngagementTrendPoint(
                  period: m['period'] as String? ?? '',
                  score: m['score'] as int? ?? 0,
                );
              })
              .toList()
          : const [],
    );
  }

  ParentAdoptionAnalytics toParentAdoption(Map<String, dynamic> json) {
    final byGradeRaw = json['adoptionByGrade'] ?? json['adoption_by_grade'];
    return ParentAdoptionAnalytics(
      totalParents: json['totalParents'] as int? ?? json['total_parents'] as int? ?? 0,
      activeParents: json['activeParents'] as int? ?? json['active_parents'] as int? ?? 0,
      pendingParents: json['pendingParents'] as int? ?? json['pending_parents'] as int? ?? 0,
      adoptionRate: json['adoptionRate'] as int? ?? json['adoption_rate'] as int? ?? 0,
      newActivations30d:
          json['newActivations30d'] as int? ?? json['new_activations_30d'] as int? ?? 0,
      adoptionByGrade: byGradeRaw is List
          ? byGradeRaw
              .map((e) {
                final m = e as Map;
                return ParentAdoptionByGrade(
                  gradeLabel: m['gradeLabel'] as String? ?? m['grade_label'] as String? ?? '',
                  total: m['total'] as int? ?? 0,
                  active: m['active'] as int? ?? 0,
                  rate: m['rate'] as int? ?? 0,
                );
              })
              .toList()
          : const [],
    );
  }
}
