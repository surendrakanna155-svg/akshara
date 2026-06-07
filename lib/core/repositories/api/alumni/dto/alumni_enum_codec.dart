import 'package:flutter/material.dart';

import '../../../../../features/alumni/alumni_models.dart';

/// Parses Alumni API enum strings and presentation helpers.
abstract final class AlumniEnumCodec {
  static AlumniEngagementStatus parseEngagementStatus(String? value) {
    return AlumniEngagementStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => AlumniEngagementStatus.active,
    );
  }

  static String engagementStatusToApi(AlumniEngagementStatus status) =>
      status.name;

  static AlumniEventStatus parseEventStatus(String? value) {
    return AlumniEventStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => AlumniEventStatus.upcoming,
    );
  }

  static String eventStatusToApi(AlumniEventStatus status) => status.name;

  static AlumniDonationStatus parseDonationStatus(String? value) {
    return AlumniDonationStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => AlumniDonationStatus.received,
    );
  }

  static String donationStatusToApi(AlumniDonationStatus status) => status.name;

  static AlumniCampaignStatus parseCampaignStatus(String? value) {
    return AlumniCampaignStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => AlumniCampaignStatus.active,
    );
  }

  static String campaignStatusToApi(AlumniCampaignStatus status) => status.name;

  static MentorshipStatus parseMentorshipStatus(String? value) {
    return MentorshipStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => MentorshipStatus.active,
    );
  }

  static String mentorshipStatusToApi(MentorshipStatus status) => status.name;

  static IconData iconForKpi(String? iconName, String? accentName) {
    if (iconName != null && iconName.isNotEmpty) {
      return switch (iconName) {
        'school_outlined' => Icons.school_outlined,
        'celebration_outlined' => Icons.celebration_outlined,
        'volunteer_activism_outlined' => Icons.volunteer_activism_outlined,
        'campaign_outlined' => Icons.campaign_outlined,
        'handshake_outlined' => Icons.handshake_outlined,
        'event_outlined' => Icons.event_outlined,
        _ => Icons.insights_outlined,
      };
    }
    return switch (accentName) {
      'primary' => Icons.school_outlined,
      'success' => Icons.volunteer_activism_outlined,
      'warning' => Icons.event_outlined,
      _ => Icons.insights_outlined,
    };
  }
}
