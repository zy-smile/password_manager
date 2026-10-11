import 'package:password_manager/features/vault/domain/entities/vault_account.dart';
import 'package:password_manager/features/vault/domain/repositories/vault_repository.dart';

class GetAccountsUseCase {
  final VaultRepository repository;

  GetAccountsUseCase(this.repository);

  Future<List<VaultAccount>> execute() {
    return repository.getAllAccounts();
  }
}
