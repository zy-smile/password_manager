import '../entities/vault_account.dart';
import '../repositories/vault_repository.dart';

class AddAccountUseCase {
  final VaultRepository repository;

  AddAccountUseCase(this.repository);

  Future<void> execute(VaultAccount account) {
    return repository.addAccount(account);
  }
}
