import '../repositories/vault_repository.dart';

class DeleteAccountUseCase {
  final VaultRepository repository;

  DeleteAccountUseCase(this.repository);

  Future<void> execute(String id) {
    return repository.deleteAccount(id);
  }
}
