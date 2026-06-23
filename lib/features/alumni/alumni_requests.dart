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
