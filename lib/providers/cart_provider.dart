import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../models/cart_item.dart';

final cartProvider =
    StateNotifierProvider<CartNotifier, List<CartItem>>((ref) => CartNotifier());

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem(Product product) {
    final index = state.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      final updated = List<CartItem>.from(state);
      updated[index] = updated[index].copyWith(
        quantity: updated[index].quantity + 1,
      );
      state = updated;
    } else {
      state = [...state, CartItem(product: product)];
    }
  }

  void removeItem(int productId) {
    state = state.where((item) => item.product.id != productId).toList();
  }

  void updateQuantity(int productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }
    final index = state.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      final updated = List<CartItem>.from(state);
      updated[index] = updated[index].copyWith(quantity: quantity);
      state = updated;
    }
  }

  void clear() {
    state = [];
  }

  double get totalAmount =>
      state.fold(0, (sum, item) => sum + item.subtotal);

  double get totalTva =>
      state.fold(0, (sum, item) => sum + item.tvaAmount);

  double get grandTotal =>
      state.fold(0, (sum, item) => sum + item.totalWithTva);

  int get totalItems =>
      state.fold(0, (sum, item) => sum + item.quantity);
}
