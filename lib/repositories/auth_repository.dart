import '../core/mcp_client.dart';
import '../core/error_handler.dart';
import '../models/user_profile.dart';

class AuthRepository {
  Future<UserProfile> signIn({
    required String username,
    required String password,
  }) async {
    try {
      final data = await mcpClient.login(
        username: username,
        password: password,
      );
      final user = data['user'] as Map<String, dynamic>? ?? {};
      return UserProfile.fromMcp(user);
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<void> signOut() async {
    try {
      await mcpClient.logout();
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<bool> hasSession() async {
    final token = await mcpClient.getToken();
    return token != null && token.isNotEmpty;
  }

  Future<UserProfile?> getCurrentUserProfile() async {
    if (!await hasSession()) return null;
    try {
      final data = await mcpClient.me();
      return UserProfile.fromMcp(data);
    } on McpApiException catch (e) {
      if (e.code == 'SESSION_EXPIRED') {
        return null;
      }
      throw Exception(humanizeError(e.message));
    }
  }
}
