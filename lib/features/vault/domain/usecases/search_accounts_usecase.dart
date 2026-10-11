import 'package:password_manager/features/vault/domain/entities/vault_account.dart';
import 'package:password_manager/features/vault/domain/repositories/vault_repository.dart';

class SearchAccountsUseCase {
  final VaultRepository repository;

  SearchAccountsUseCase(this.repository);

  Future<List<VaultAccount>> execute(String query) {
    return repository.searchAccounts(query);
  }
}
