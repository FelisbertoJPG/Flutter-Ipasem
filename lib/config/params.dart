// lib/config/params.dart
class AppParams {
  final String adminEmail;
  final String supportEmail;
  final String senderEmail;
  final String senderName;
  final Duration passwordResetTokenExpire;
  final int passwordMinLength;
  final String baseApiUrl; // <—

  const AppParams({
    required this.adminEmail,
    required this.supportEmail,
    required this.senderEmail,
    required this.senderName,
    required this.passwordResetTokenExpire,
    required this.passwordMinLength,
    required this.baseApiUrl,
  });

  factory AppParams.fromEnv() {
    const adminEmail   = String.fromEnvironment('ADMIN_EMAIL',  defaultValue: 'admin@example.com');
    const supportEmail = String.fromEnvironment('SUPPORT_EMAIL',defaultValue: 'support@example.com');
    const senderEmail  = String.fromEnvironment('SENDER_EMAIL', defaultValue: 'noreply@example.com');
    const senderName   = String.fromEnvironment('SENDER_NAME',  defaultValue: 'Example.com mailer');
    const resetExpire  = int.fromEnvironment('USER_PASSWORD_RESET_TOKEN_EXPIRE', defaultValue: 3600);
    const minLength    = int.fromEnvironment('USER_PASSWORD_MIN_LENGTH',        defaultValue: 8);
    const baseApiUrl   = String.fromEnvironment('BASE_API_URL', defaultValue: 'http://10.0.2.2:8080'); // emulador Android

    return AppParams(
      adminEmail: adminEmail,
      supportEmail: supportEmail,
      senderEmail: senderEmail,
      senderName: senderName,
      passwordResetTokenExpire: Duration(seconds: resetExpire),
      passwordMinLength: minLength,
      baseApiUrl: baseApiUrl,
    );
  }
}
