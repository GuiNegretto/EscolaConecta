import 'api_routes.dart';

class AppConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    //defaultValue: 'http://localhost:3000/api',
    defaultValue: 'https://escolaconecta-api-gfos.onrender.com/api',
  );

  // Endpoints
  static const String loginEndpoint = ApiRoutes.login;
  static const String changePasswordEndpoint = ApiRoutes.changePassword;

  static const String adminMessagesEndpoint = ApiRoutes.adminMessages;
  static const String adminStudentsEndpoint = ApiRoutes.adminStudents;
  static const String adminGuardiansEndpoint = ApiRoutes.adminGuardians;

  static const String guardianMessagesEndpoint = ApiRoutes.guardianMessages;
  static const String guardianProfileEndpoint = ApiRoutes.guardianProfile;

  static const String uploadsImagesEndpoint = '/uploads/images';
  static const String uploadsVideosEndpoint = '/uploads/videos';

    // Aliases expected by api_service.dart
  static const String profileEndpoint = guardianProfileEndpoint;
  static const String messagesEndpoint = guardianMessagesEndpoint;
  static const String sendMessageEndpoint = adminMessagesEndpoint;
  static const String studentsEndpoint = adminStudentsEndpoint;
  static const String parentsEndpoint = adminGuardiansEndpoint;
}