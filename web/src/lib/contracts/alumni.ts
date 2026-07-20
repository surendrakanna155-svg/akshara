/** Alumni contracts — mirror lib/features/alumni/alumni_models.dart. */
export type AlumniEngagementStatus = 'active' | 'inactive' | 'pending';
export type AlumniEventStatus = 'upcoming' | 'ongoing' | 'completed' | 'cancelled';
export type AlumniDonationStatus = 'received' | 'pledged' | 'pending' | 'refunded';
export type AlumniCampaignStatus = 'active' | 'draft' | 'completed' | 'paused';
export type MentorshipStatus = 'active' | 'pending' | 'completed' | 'onHold';

export interface AlumniRecord {
  id: string;
  name: string;
  batchYear: string;
  program: string;
  currentRole: string;
  city: string;
  email: string;
  phone: string;
  engagementStatus: AlumniEngagementStatus;
  totalDonated: string;
  lastEventAttended: string;
}

export interface AlumniEvent {
  id: string;
  title: string;
  date: string;
  venue: string;
  registrations: number;
  capacity: number;
  status: AlumniEventStatus;
  organizer: string;
}

export interface AlumniDonation {
  id: string;
  alumniName: string;
  amount: string;
  date: string;
  campaign: string;
  status: AlumniDonationStatus;
  paymentMode: string;
}

export interface AlumniCampaign {
  id: string;
  name: string;
  goalAmount: string;
  raisedAmount: string;
  donorCount: number;
  deadline: string;
  status: AlumniCampaignStatus;
}

export interface MentorshipPair {
  id: string;
  mentorName: string;
  menteeName: string;
  focusArea: string;
  status: MentorshipStatus;
  startedDate: string;
}

export interface AlumniKpi {
  id: string;
  label: string;
  value: string;
  delta?: number;
}

export interface AlumniDashboardData {
  kpis: AlumniKpi[];
}
