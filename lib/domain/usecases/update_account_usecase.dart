import '../entities/vault_account.dart';
import '../repositories/vault_repository.dart';

class UpdateAccountUseCase {
  final VaultRepository repository;

  UpdateAccountUseCase(this.repository);

  Future<void> execute(VaultAccount account) {
    return repository.updateAccount(account);
  }
}
