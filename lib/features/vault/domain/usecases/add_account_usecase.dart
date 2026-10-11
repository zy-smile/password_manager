import 'package:password_manager/features/vault/domain/entities/vault_account.dart';
import 'package:password_manager/features/vault/domain/repositories/vault_repository.dart';

class AddAccountUseCase {
  final VaultRepository repository;

  AddAccountUseCase(this.repository);

  Future<void> execute(VaultAccount account) {
    return repository.addAccount(account);
  }
}
