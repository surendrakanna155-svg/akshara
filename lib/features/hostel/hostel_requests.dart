import 'hostel_models.dart';

class AdmitHostelStudentRequest {
  const AdmitHostelStudentRequest({
    required this.sisStudentId,
    required this.studentName,
    required this.admissionNumber,
    required this.classLabel,
  });

  final String sisStudentId;
  final String studentName;
  final String admissionNumber;
  final String classLabel;
}

class AssignHostelRoomRequest {
  const AssignHostelRoomRequest({
    required this.hostelStudentId,
    required this.roomId,
    required this.bed,
  });

  final String hostelStudentId;
  final String roomId;
  final String bed;
}

class CheckoutHostelStudentRequest {
  const CheckoutHostelStudentRequest({required this.hostelStudentId});

  final String hostelStudentId;
}

class CreateHostelRoomRequest {
  const CreateHostelRoomRequest({
    required this.block,
    required this.roomNumber,
    required this.floor,
    required this.type,
    required this.totalBeds,
    required this.facilities,
  });

  final String block;
  final String roomNumber;
  final int floor;
  final HostelRoomType type;
  final int totalBeds;
  final String facilities;
}
