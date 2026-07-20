/** Library contracts — mirror lib/features/library/library_models.dart. */
export type LibraryBookStatus = 'available' | 'issued' | 'reserved' | 'damaged';
export type LibraryMemberType = 'student' | 'staff' | 'teacher';
export type LibraryMemberStatus = 'active' | 'blocked' | 'expired';
export type LibraryLoanStatus = 'active' | 'overdue' | 'returned';
export type LibraryFineStatus = 'pending' | 'paid' | 'waived';
export type LibraryResourceType = 'ebook' | 'pdf' | 'link' | 'video';

export interface LibraryBook {
  id: string;
  isbn: string;
  title: string;
  author: string;
  category: string;
  totalCopies: number;
  availableCopies: number;
  shelf: string;
  status: LibraryBookStatus;
}

export interface LibraryMember {
  id: string;
  name: string;
  memberType: LibraryMemberType;
  identifier: string;
  classOrDepartment: string;
  activeLoans: number;
  status: LibraryMemberStatus;
}

export interface LibraryIssueRecord {
  id: string;
  memberName: string;
  memberType: LibraryMemberType;
  bookTitle: string;
  isbn: string;
  issuedDate: string;
  dueDate: string;
  status: LibraryLoanStatus;
}

export interface LibraryReturnRecord {
  id: string;
  memberName: string;
  bookTitle: string;
  isbn: string;
  returnedDate: string;
  condition: 'good' | 'fair' | 'damaged';
  fineAmount: string;
  daysOverdue: number;
}

export interface LibraryFine {
  id: string;
  memberName: string;
  bookTitle: string;
  amount: string;
  daysOverdue: number;
  status: LibraryFineStatus;
  financeLinked: boolean;
}

export interface LibraryDigitalResource {
  id: string;
  title: string;
  type: LibraryResourceType;
  classAccess: string;
  downloads: number;
  studentAppVisible: boolean;
  teacherAppVisible: boolean;
  resourceUrl?: string;
}

export interface LibraryKpi {
  id: string;
  label: string;
  value: string;
  delta?: number;
}

export interface LibraryDashboardData {
  kpis: LibraryKpi[];
}
