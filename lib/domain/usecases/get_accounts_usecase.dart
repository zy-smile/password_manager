import '../entities/vault_account.dart';
import '../repositories/vault_repository.dart';

class GetAccountsUseCase {
  final VaultRepository repository;

  GetAccountsUseCase(this.repository);

  Future<List<VaultAccount>> execute() {
    return repository.getAllAccounts();
  }
}
