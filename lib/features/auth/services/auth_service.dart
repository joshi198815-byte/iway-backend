import 'package:iway_app/features/auth/models/traveler_type.dart';
import 'package:iway_app/features/auth/models/user_model.dart';
import 'package:iway_app/features/notifications/services/push_notification_service.dart';
import 'package:iway_app/services/api_client.dart';
import 'package:iway_app/services/session_service.dart';

class AuthService {
  AuthService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<UserModel?> login(String email, String password) async {
    final data = await _apiClient.post('/auth/login', {
      'email': email.trim().toLowerCase(),
      'password': password.trim(),
    });

    final user = data['user'];
    if (user is! Map<String, dynamic>) {
      return null;
    }

    final parsedUser = UserModel.fromBackendJson(user);
    await SessionService.setUser(
      parsedUser,
      accessToken: data['accessToken']?.toString(),
    );
    await PushNotificationService.syncTokenIfPossible();
    return parsedUser;
  }

  Future<UserModel?> registerCustomer({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    String? countryCode,
    String? stateRegion,
    String? city,
    String? address,
  }) async {
    final data = await _apiClient.post('/auth/register/customer', {
      'fullName': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'password': password.trim(),
      'countryCode': countryCode,
      'stateRegion': stateRegion,
      'city': city,
      'address': address,
    });

    final user = data['user'];
    if (user is! Map<String, dynamic>) {
      return null;
    }

    final parsedUser = UserModel.fromBackendJson(user);
    await SessionService.setUser(
      parsedUser,
      accessToken: data['accessToken']?.toString(),
    );
    await PushNotificationService.syncTokenIfPossible();
    return parsedUser;
  }

  Future<UserModel?> registerTraveler({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required TravelerType travelerType,
    required String documentNumber,
    String? countryCode,
    String? stateRegion,
    String? city,
    String? address,
    String? detectedCountryCode,
    String? documentUrl,
    String? selfieUrl,
    String? documentBase64,
    String? selfieBase64,
  }) async {
    final data = await _apiClient.post('/auth/register/traveler', {
      'fullName': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'password': password.trim(),
      'travelerType': travelerType.apiValue,
      'documentNumber': documentNumber.trim(),
      'countryCode': countryCode,
      'stateRegion': stateRegion,
      'city': city,
      'address': address,
      'detectedCountryCode': detectedCountryCode,
      'documentUrl': documentUrl,
      'selfieUrl': selfieUrl,
      'documentBase64': documentBase64,
      'selfieBase64': selfieBase64,
    });

    final user = data['user'];
    if (user is! Map<String, dynamic>) {
      return null;
    }

    final parsedUser = UserModel.fromBackendJson(user);
    await SessionService.setUser(
      parsedUser,
      accessToken: data['accessToken']?.toString(),
    );
    await PushNotificationService.syncTokenIfPossible();
    return parsedUser;
  }

  Future<void> requestVerificationCode(String channel) {
    return _apiClient.post('/auth/verification-code', {
      'channel': channel,
    });
  }

  Future<UserModel?> verifyContactCode({
    required String channel,
    required String code,
  }) async {
    final data = await _apiClient.post('/auth/verify-contact', {
      'channel': channel,
      'code': code.trim(),
    });

    final user = data['user'];
    if (user is! Map<String, dynamic>) return null;

    final parsedUser = UserModel.fromBackendJson(user);
    await SessionService.setUser(
      parsedUser,
      accessToken: SessionService.currentAccessToken,
    );
    return parsedUser;
  }

  Future<UserModel?> refreshCurrentUser() async {
    final data = await _apiClient.get('/auth/me');
    if (data is! Map<String, dynamic>) return null;

    final user = data['user'];
    if (user is! Map<String, dynamic>) return null;

    final parsedUser = UserModel.fromBackendJson(user);
    await SessionService.setUser(
      parsedUser,
      accessToken: SessionService.currentAccessToken,
    );
    return parsedUser;
  }
}
