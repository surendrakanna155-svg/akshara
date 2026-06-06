import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admissions_models.dart';

final admissionsLeadsLoadingProvider = StateProvider<bool>((ref) => false);
final admissionsLeadsErrorProvider = StateProvider<bool>((ref) => false);
final admissionsLeadsEmptyProvider = StateProvider<bool>((ref) => false);

final admissionsLeadsFilterProvider = StateProvider<int>((ref) => 0);

final admissionsLeadsProvider = Provider<List<AdmissionsLead>>((ref) {
  if (ref.watch(admissionsLeadsLoadingProvider)) return const [];
  if (ref.watch(admissionsLeadsErrorProvider)) return const [];
  if (ref.watch(admissionsLeadsEmptyProvider)) return const [];
  return _mockLeads();
});

List<AdmissionsLead> _mockLeads() {
  return const [
    AdmissionsLead(
      id: 'LD-1042',
      parentName: 'Rajesh Reddy',
      studentName: 'Ananya Reddy',
      classLabel: '5',
      phone: '+91 98765 43210',
      source: LeadSource.walkIn,
      campaign: 'Summer Open Day',
      stage: LeadStage.schoolVisit,
      counselor: 'Meera N.',
      score: LeadScore.hot,
      nextFollowUpLabel: '5 Jun · 10:00 AM',
    ),
    AdmissionsLead(
      id: 'LD-1038',
      parentName: 'Lakshmi Sharma',
      studentName: 'Karthik Sharma',
      classLabel: '8',
      phone: '+91 91234 56789',
      source: LeadSource.website,
      campaign: 'Organic — Homepage',
      stage: LeadStage.demoClass,
      counselor: 'Rahul V.',
      score: LeadScore.warm,
      nextFollowUpLabel: '6 Jun · 11:30 AM',
    ),
    AdmissionsLead(
      id: 'LD-1031',
      parentName: 'Suresh Menon',
      studentName: 'Priya Menon',
      classLabel: '3',
      phone: '+91 99887 76655',
      source: LeadSource.whatsapp,
      campaign: 'WA Broadcast Q2',
      stage: LeadStage.followUp,
      counselor: 'Meera N.',
      score: LeadScore.hot,
      nextFollowUpLabel: '5 Jun · 2:00 PM',
    ),
    AdmissionsLead(
      id: 'LD-1024',
      parentName: 'Anita Patel',
      studentName: 'Arjun Patel',
      classLabel: '10',
      phone: '+91 97654 32109',
      source: LeadSource.referral,
      campaign: 'Parent referral — Grade 9',
      stage: LeadStage.admissionConfirmed,
      counselor: 'Sneha K.',
      score: LeadScore.warm,
      nextFollowUpLabel: '7 Jun · 9:00 AM',
    ),
    AdmissionsLead(
      id: 'LD-1019',
      parentName: 'Vikram Iyer',
      studentName: 'Divya Iyer',
      classLabel: '6',
      phone: '+91 96543 21098',
      source: LeadSource.googleAds,
      campaign: 'Search — Best school',
      stage: LeadStage.contacted,
      counselor: 'Arun D.',
      score: LeadScore.cold,
      nextFollowUpLabel: '8 Jun · 4:00 PM',
    ),
    AdmissionsLead(
      id: 'LD-1012',
      parentName: 'Meena Krishnan',
      studentName: 'Rohan Krishnan',
      classLabel: '1',
      phone: '+91 95432 10987',
      source: LeadSource.facebook,
      campaign: 'FB Lead Gen — Nursery',
      stage: LeadStage.newEnquiry,
      counselor: 'Rahul V.',
      score: LeadScore.warm,
      nextFollowUpLabel: '5 Jun · 5:30 PM',
    ),
    AdmissionsLead(
      id: 'LD-1008',
      parentName: 'Joseph Thomas',
      studentName: 'Emma Thomas',
      classLabel: '7',
      phone: '+91 94321 09876',
      source: LeadSource.walkIn,
      campaign: 'Campus tour — May',
      stage: LeadStage.joined,
      counselor: 'Sneha K.',
      score: LeadScore.hot,
      nextFollowUpLabel: 'Completed',
    ),
  ];
}
