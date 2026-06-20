import 'dart:math';

class PasswordGenerator {
  static const String _lowercase = 'abcdefghijklmnopqrstuvwxyz';
  static const String _uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _numbers = '0123456789';
  static const String _specialChars = '!@#\$%^&*()_+-=[]{}|;:,.<>?';

  static String generate({
    int length = 16,
    bool includeUppercase = true,
    bool includeLowercase = true,
    bool includeNumbers = true,
    bool includeSpecialChars = true,
  }) {
    final random = Random.secure();
    final pools = <String>[
      if (includeLowercase) _lowercase,
      if (includeUppercase) _uppercase,
      if (includeNumbers) _numbers,
      if (includeSpecialChars) _specialChars,
    ];

    if (pools.isEmpty) {
      pools.add(_lowercase);
    }

    final allCharacters = pools.join();
    final passwordCharacters = <String>[
      for (final pool in pools) pool[random.nextInt(pool.length)],
    ];

    while (passwordCharacters.length < length) {
      passwordCharacters.add(
        allCharacters[random.nextInt(allCharacters.length)],
      );
    }

    passwordCharacters.shuffle(random);
    return passwordCharacters.join();
  }
}
