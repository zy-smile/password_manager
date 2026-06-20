import 'package:flutter_test/flutter_test.dart';

import 'package:password_manager/core/utils/password_generator.dart';

void main() {
  group('PasswordGenerator', () {
    test('generated password matches requested length', () {
      final password = PasswordGenerator.generate(length: 24);
      expect(password.length, equals(24));
    });

    test('generated password includes all selected character groups', () {
      final password = PasswordGenerator.generate(
        length: 20,
        includeUppercase: true,
        includeLowercase: true,
        includeNumbers: true,
        includeSpecialChars: true,
      );

      expect(password.contains(RegExp(r'[A-Z]')), isTrue);
      expect(password.contains(RegExp(r'[a-z]')), isTrue);
      expect(password.contains(RegExp(r'[0-9]')), isTrue);
      expect(password.contains(RegExp(r'[!@#\$%^&*()_+\-=\[\]{}|;:,.<>?]')),
          isTrue);
    });
  });
}
