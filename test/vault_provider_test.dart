import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/features/vault/data/repositories/vault_repository_impl.dart';
import 'package:password_manager/features/vault/domain/entities/vault_account.dart';
import 'package:password_manager/features/vault/presentation/providers/vault_provider.dart';
import 'support/fakes.dart';

class DelayedRepository extends VaultRepositoryImpl {
  DelayedRepository() : super(MemoryVaultDataSource());
  Completer<List<VaultAccount>>? pending;
  int reads = 0;
  @override
  Future<List<VaultAccount>> getAllAccounts() {
    reads++;
    return pending!.future;
  }
}

VaultAccount account(int index) => VaultAccount(
    id: '$index',
    title: 'Site $index',
    website: 'https://site$index.example',
    username: 'user$index',
    password: 'secret',
    category: index.isEven ? '工作' : '社交',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026));

void main() {
  test('locking clears cached plaintext and rejects a pending load result',
      () async {
    final auth = SessionTestAuth();
    final repository = DelayedRepository();
    final vault = VaultProvider(repository: repository)..updateAuth(auth);
    repository.pending = Completer();
    final loading = vault.loadAccounts();
    auth.lock();
    repository.pending!.complete([account(1)]);
    await loading;
    expect(vault.accounts, isEmpty);
    expect(vault.isLoading, isFalse);
    vault.dispose();
    auth.dispose();
  });

  test('10,000-record search filters cache without further database reads',
      () async {
    final auth = SessionTestAuth();
    final repository = DelayedRepository();
    final vault = VaultProvider(repository: repository)..updateAuth(auth);
    repository.pending = Completer()..complete(List.generate(10000, account));
    await vault.loadAccounts();
    final stopwatch = Stopwatch()..start();
    vault.setSearchQuery('user9999');
    stopwatch.stop();
    expect(vault.accounts.single.id, '9999');
    expect(repository.reads, 1);
    expect(stopwatch.elapsedMilliseconds, lessThan(300));
    vault.setSelectedCategory('工作');
    expect(vault.accounts, isEmpty);
    vault.clearFilters();
    expect(vault.accounts.length, 10000);
    auth.lock();
    expect(vault.accounts, isEmpty);
    vault.clearFilters();
    expect(vault.accounts, isEmpty);
    vault.dispose();
    auth.dispose();
  });
}
