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
