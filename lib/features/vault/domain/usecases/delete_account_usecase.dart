import 'package:password_manager/features/vault/domain/repositories/vault_repository.dart';

class DeleteAccountUseCase {
  final VaultRepository repository;

  DeleteAccountUseCase(this.repository);

  Future<void> execute(String id) {
    return repository.deleteAccount(id);
  }
}
