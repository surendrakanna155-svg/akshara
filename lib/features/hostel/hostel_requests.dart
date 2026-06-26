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

class RecordHostelAttendanceRequest {
  const RecordHostelAttendanceRequest({
    required this.studentName,
    required this.room,
    required this.rollNumber,
    required this.morning,
    required this.evening,
    required this.night,
    required this.remark,
    required this.sisStudentId,
  });

  final String studentName;
  final String room;
  final String rollNumber;
  final HostelAttendanceStatus morning;
  final HostelAttendanceStatus evening;
  final HostelAttendanceStatus night;
  final String remark;
  final String sisStudentId;
}

class RecordMessRequest {
  const RecordMessRequest({
    required this.day,
    required this.mealType,
    required this.items,
    required this.dietaryTags,
    required this.headcount,
    required this.costRupees,
  });

  final String day;
  final HostelMealType mealType;
  final String items;
  final List<String> dietaryTags;
  final int headcount;
  final int costRupees;
}

class LogVisitorRequest {
  const LogVisitorRequest({
    required this.visitorName,
    required this.relation,
    required this.studentName,
    required this.sisStudentId,
  });

  final String visitorName;
  final String relation;
  final String studentName;
  final String sisStudentId;
}
