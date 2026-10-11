import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encryption;
import 'package:password_manager/features/vault/data/models/vault_account_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/core/encryption/aes_service.dart';
import 'package:password_manager/core/encryption/key_derivation.dart';
import 'package:password_manager/features/vault/data/repositories/vault_repository_impl.dart';
import 'package:password_manager/features/vault/presentation/providers/auth_provider.dart';
import 'support/fakes.dart';

void main() {
  late MemorySecureStorage storage;
  late AuthProvider auth;
  setUp(() async {
    storage = MemorySecureStorage();
    auth = AuthProvider(
        secureStorage: storage,
        biometricService: FakeBiometricService(),
        repository: VaultRepositoryImpl(MemoryVaultDataSource()));
    await auth.init();
  });
  tearDown(() => auth.dispose());

  test('new master password requires length and a number', () async {
    await expectLater(auth.setupMasterPassword('short1'), throwsException);
    await expectLater(auth.setupMasterPassword('abcdefgh'), throwsException);
    expect(storage.state, isNull);
  });

  test('password change preserves data key and existing ciphertext', () async {
    await auth.setupMasterPassword(' old password1 ');
    final key = auth.encryptionKey!;
    final ciphertext = await AesService.encrypt('saved-secret', key);
    await auth.changeMasterPassword(' old password1 ', ' new password2 ');
    expect(auth.encryptionKey, key);
    auth.lock();
    expect(await auth.authenticate(' old password1 '), isFalse);
    expect(await auth.authenticate(' new password2 '), isTrue);
    expect(await AesService.decrypt(ciphertext, auth.encryptionKey!),
        'saved-secret');
    final restarted = AuthProvider(
        secureStorage: storage, biometricService: FakeBiometricService());
    await restarted.init();
    expect(await restarted.authenticate(' new password2 '), isTrue);
    expect(restarted.encryptionKey, key);
    restarted.dispose();
  });

  test('failed password-record write leaves old password and data usable',
      () async {
    await auth.setupMasterPassword('old-password1');
    final record = storage.state;
    final key = auth.encryptionKey;
    storage.failNextStateWrite = true;
    await expectLater(
        auth.changeMasterPassword('old-password1', 'new-password2'),
        throwsStateError);
    expect(storage.state, record);
    auth.lock();
    expect(await auth.authenticate('old-password1'), isTrue);
    expect(auth.encryptionKey, key);
  });

  test('five failed attempts enter cooldown', () async {
    await auth.setupMasterPassword('master-password1');
    auth.lock();
    for (var i = 0; i < 5; i++) {
      expect(await auth.authenticate('wrong'), isFalse);
    }
    expect(auth.isTemporarilyLocked, isTrue);
    expect(await auth.authenticate('master-password1'), isFalse);
    expect(auth.encryptionKey, isNull);
  });

  test('v2 account upgrades to a wrapped key without changing its data key',
      () async {
    const salt = 'c2FsdC1mb3ItdGVzdC0xMA==';
    final bytes = await KeyDerivation.deriveKeyBytes('legacy-password1', salt);
    final key = await KeyDerivation.deriveKey('legacy-password1', salt);
    storage.salt = salt;
    storage.hash = KeyDerivation.buildPasswordVerifier(bytes);
    storage.version = '2';
    await auth.init();
    expect(await auth.authenticate('legacy-password1'), isTrue);
    expect(auth.encryptionKey, key);
    expect(storage.state, isNotNull);
  });

  test('locking during password verification prevents delayed unlock',
      () async {
    await auth.setupMasterPassword('master-password1');
    auth.lock();
    final pending = auth.authenticate('master-password1');
    auth.lock();
    expect(await pending, isFalse);
    expect(auth.isUnlocked, isFalse);
    expect(auth.encryptionKey, isNull);
  });
  test('legacy migration retries after failure to save the new auth record',
      () async {
    const password = 'legacy-password1';
    final salt = KeyDerivation.generateSalt();
    List<int> hash = utf8.encode(password);
    for (var i = 0; i < 100000; i++) {
      hash = sha256.convert([...hash, ...utf8.encode(salt)]).bytes;
    }
    storage.hash = base64Encode(hash);
    storage.salt = salt;
    storage.version = '1';
    final data = MemoryVaultDataSource();
    final key = encryption.Key(Uint8List.fromList(List.generate(
        32,
        (index) =>
            (index < password.length ? password.codeUnitAt(index) : 0) ^
            (index * 17))));
    final iv = encryption.IV.fromSecureRandom(16);
    final cipher =
        encryption.Encrypter(encryption.AES(key, mode: encryption.AESMode.cbc))
            .encrypt('legacy-secret', iv: iv);
    data.records.add(VaultAccountModel(
        id: 'legacy',
        title: 'Legacy',
        website: '',
        username: 'legacy-user',
        passwordEncrypted: base64Encode([...iv.bytes, ...cipher.bytes]),
        note: 'legacy-note',
        encryptionVersion: 1,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026)));
    final repository = VaultRepositoryImpl(data);
    final legacyAuth = AuthProvider(
        secureStorage: storage,
        biometricService: FakeBiometricService(),
        repository: repository);
    await legacyAuth.init();
    storage.failNextStateWrite = true;
    await expectLater(legacyAuth.authenticate(password), throwsStateError);
    expect(data.records.single.encryptionVersion, 2);
    expect(storage.version, '1');
    final retryAuth = AuthProvider(
        secureStorage: storage,
        biometricService: FakeBiometricService(),
        repository: repository);
    await retryAuth.init();
    expect(await retryAuth.authenticate(password), isTrue);
    repository.setEncryptionKey(retryAuth.encryptionKey!);
    final account = (await repository.getAllAccounts()).single;
    expect(account.password, 'legacy-secret');
    expect(account.username, 'legacy-user');
    expect(account.note, 'legacy-note');
    expect(data.records.single.username, isNull);
    expect(data.records.single.note, isNull);
    legacyAuth.dispose();
    retryAuth.dispose();
  });
}
