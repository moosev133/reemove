abstract final class AuthValidators {
  static final RegExp _emailPattern = RegExp(
    r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
    caseSensitive: false,
  );
  static final RegExp _usernamePattern = RegExp(r'^[a-z0-9._]{3,30}$');
  static final RegExp _repeatedSeparatorPattern = RegExp(r'[._]{2,}');
  static const Set<String> _reservedUsernames = <String>{
    'admin',
    'administrator',
    'api',
    'app',
    'auth',
    'contact',
    'help',
    'moderator',
    'reemove',
    'security',
    'staff',
    'support',
    'system',
    'team',
    'verified',
  };

  static String normalizeEmail(String value) => value.trim().toLowerCase();

  static String normalizeUsername(String value) => value.trim().toLowerCase();

  static String? email(String? value) {
    final String email = normalizeEmail(value ?? '');
    if (email.isEmpty) {
      return 'Enter your email address.';
    }
    if (email.length > 254 || !_emailPattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? password(String? value) {
    final String password = value ?? '';
    if (password.isEmpty) {
      return 'Enter your password.';
    }
    if (password.length < 8) {
      return 'Use at least 8 characters.';
    }
    if (password.length > 128) {
      return 'Use no more than 128 characters.';
    }
    return null;
  }

  static String? strongPassword(String? value) {
    final String? basicError = AuthValidators.password(value);
    if (basicError != null) {
      return basicError;
    }
    final String candidate = value!;
    if (!RegExp('[A-Za-z]').hasMatch(candidate) ||
        !RegExp('[0-9]').hasMatch(candidate)) {
      return 'Include at least one letter and one number.';
    }
    return null;
  }

  static String? displayName(String? value) {
    final String name = (value ?? '').trim();
    if (name.isEmpty) {
      return 'Enter your name.';
    }
    if (name.length > 80) {
      return 'Use no more than 80 characters.';
    }
    return null;
  }

  static String? username(String? value) {
    final String username = normalizeUsername(value ?? '');
    if (username.length < 3) {
      return 'Use at least 3 characters.';
    }
    if (username.length > 30) {
      return 'Use no more than 30 characters.';
    }
    if (!_usernamePattern.hasMatch(username)) {
      return 'Use lowercase letters, numbers, dots, or underscores.';
    }
    if (!RegExp(r'^[a-z0-9]').hasMatch(username) ||
        !RegExp(r'[a-z0-9]$').hasMatch(username)) {
      return 'Start and end with a letter or number.';
    }
    if (_repeatedSeparatorPattern.hasMatch(username)) {
      return 'Do not repeat dots or underscores.';
    }
    if (_reservedUsernames.contains(username)) {
      return 'That username is reserved.';
    }
    return null;
  }
}
