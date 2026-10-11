import 'package:password_manager/features/vault/domain/repositories/vault_repository.dart';

class ToggleFavoriteUseCase {
  final VaultRepository repository;

  ToggleFavoriteUseCase(this.repository);

  Future<void> execute(String id, bool isFavorite) {
    return repository.toggleFavorite(id, isFavorite);
  }
}
