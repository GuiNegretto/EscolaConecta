class ApiRoutes {
  static const String auth = '/auth';
  static const String login = '$auth/login';
  static const String changePassword = '$auth/change-password';

  static const String adminMessages = '/admin/messages';
  static String adminMessage(String id) => '$adminMessages/$id';
  static const String adminStudents = '/admin/students';
  static String adminStudent(String id) => '$adminStudents/$id';
  static const String adminGuardians = '/admin/guardians';
  static String adminGuardian(String id) => '$adminGuardians/$id';

  static const String guardianMessages = '/guardian/messages';
  static String guardianMessage(String id) => '$guardianMessages/$id';
  static const String guardianProfile = '/guardian/profile';

  static String uploadsImages(String filename) => '/uploads/images/$filename';
  static String uploadsVideos(String filename) => '/uploads/videos/$filename';
}