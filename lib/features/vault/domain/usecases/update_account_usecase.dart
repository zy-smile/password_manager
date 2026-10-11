import 'package:password_manager/features/vault/domain/entities/vault_account.dart';
import 'package:password_manager/features/vault/domain/repositories/vault_repository.dart';

class UpdateAccountUseCase {
  final VaultRepository repository;

  UpdateAccountUseCase(this.repository);

  Future<void> execute(VaultAccount account) {
    return repository.updateAccount(account);
  }
}
