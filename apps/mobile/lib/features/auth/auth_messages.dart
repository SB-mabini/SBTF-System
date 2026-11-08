/// Turns the raw Supabase Auth message into a sentence a driver can act on.
///
/// Supabase returns stable English strings such as "Invalid login credentials"
/// and "Token has expired or is invalid". They are accurate but read like
/// server output, so every auth screen funnels them through this one helper to
/// keep the wording identical across sign-in, registration, OTP and password
/// reset.
String friendlyAuthMessage(String message) {
  final lower = message.toLowerCase();

  if (lower.contains('invalid login credentials')) {
    return 'The e-mail address or password is incorrect.';
  }
  if (lower.contains('email not confirmed')) {
    return 'Your e-mail address has not been confirmed yet. '
        'Enter the 6-digit code we sent you.';
  }
  if (lower.contains('user already registered') ||
      lower.contains('already been registered')) {
    return 'An account with this e-mail already exists. Sign in instead, '
        'or use “Forgot password?”.';
  }
  if (lower.contains('token has expired') ||
      lower.contains('invalid token') ||
      lower.contains('invalid otp') ||
      (lower.contains('otp') && lower.contains('expired'))) {
    return 'That code is incorrect or has expired. Request a new code and '
        'try again.';
  }
  if (lower.contains('rate limit') ||
      lower.contains('too many requests') ||
      lower.contains('email rate limit exceeded')) {
    return 'Too many code requests. Wait a minute, then try again.';
  }
  if (lower.contains('password should be') ||
      lower.contains('weak password') ||
      lower.contains('password is too short')) {
    return 'Choose a stronger password — at least 8 characters.';
  }
  if (lower.contains('same password') ||
      lower.contains('different from the old password')) {
    return 'The new password must be different from your current password.';
  }
  if (lower.contains('auth session missing')) {
    return 'Your verification session has expired. Request a new code and '
        'try again.';
  }
  // Network / offline errors — Supabase wraps SocketException inside
  // AuthException on Android, so the raw OS error leaks into the message.
  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('no address associated') ||
      lower.contains('clientexception') ||
      lower.contains('network')) {
    return 'No internet connection. Please check your network and try again.';
  }

  return message;
}
