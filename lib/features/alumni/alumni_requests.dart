class AddAlumniRequest {
  const AddAlumniRequest({
    required this.name,
    required this.batchYear,
    required this.program,
    required this.currentRole,
    required this.city,
    required this.email,
    required this.phone,
  });

  final String name;
  final String batchYear;
  final String program;
  final String currentRole;
  final String city;
  final String email;
  final String phone;
}

class CreateAlumniEventRequest {
  const CreateAlumniEventRequest({
    required this.title,
    required this.date,
    required this.venue,
    required this.capacity,
    required this.organizer,
  });

  final String title;
  final String date;
  final String venue;
  final String capacity;
  final String organizer;
}

class CreateAlumniCampaignRequest {
  const CreateAlumniCampaignRequest({
    required this.name,
    required this.goalAmount,
    required this.deadline,
    required this.financeAccountCode,
  });

  final String name;
  final String goalAmount;
  final String deadline;
  final String financeAccountCode;
}

class RecordDonationRequest {
  const RecordDonationRequest({
    required this.alumniName,
    required this.alumniId,
    required this.amount,
    required this.date,
    required this.campaignId,
    required this.status,
    required this.paymentMode,
  });

  final String alumniName;
  final String alumniId;
  final String amount;
  final String date;

  /// Optional id of the campaign this donation funds ('' when unattributed).
  final String campaignId;
  final String status;
  final String paymentMode;
}

class AddMentorshipPairRequest {
  const AddMentorshipPairRequest({
    required this.mentorName,
    required this.mentorAlumniId,
    required this.menteeName,
    required this.menteeBatch,
    required this.focusArea,
  });

  final String mentorName;
  final String mentorAlumniId;
  final String menteeName;
  final String menteeBatch;
  final String focusArea;
}
