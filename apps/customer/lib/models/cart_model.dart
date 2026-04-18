import 'package:flutter/foundation.dart';

class CartItem {
  final String foodId;
  final String title;
  final String? image;
  final int quantity;
  final String? variationId;
  final String? variationTitle;
  final int unitPrice;
  final List<Map<String, dynamic>> addons;

  CartItem({
    required this.foodId,
    required this.title,
    this.image,
    required this.quantity,
    this.variationId,
    this.variationTitle,
    required this.unitPrice,
    this.addons = const [],
  });

  int get totalPrice => unitPrice * quantity;

  CartItem copyWith({int? quantity}) => CartItem(
        foodId: foodId,
        title: title,
        image: image,
        quantity: quantity ?? this.quantity,
        variationId: variationId,
        variationTitle: variationTitle,
        unitPrice: unitPrice,
        addons: addons,
      );
}

class CartModel extends ChangeNotifier {
  final List<CartItem> _items = [];
  String? _restaurantId;
  String? _restaurantName;

  List<CartItem> get items => List.unmodifiable(_items);
  String? get restaurantId => _restaurantId;
  String? get restaurantName => _restaurantName;
  bool get isEmpty => _items.isEmpty;

  int get itemCount => _items.fold(0, (s, i) => s + i.quantity);

  int get totalSats => _items.fold(0, (s, i) => s + i.totalPrice);

  void addItem(CartItem item, String restaurantId, String restaurantName) {
    if (_restaurantId != null && _restaurantId != restaurantId) {
      _items.clear();
    }
    _restaurantId = restaurantId;
    _restaurantName = restaurantName;

    final idx = _items.indexWhere(
      (i) => i.foodId == item.foodId && i.variationId == item.variationId,
    );
    if (idx >= 0) {
      _items[idx] = _items[idx].copyWith(quantity: _items[idx].quantity + item.quantity);
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void removeItem(String foodId, {String? variationId}) {
    _items.removeWhere((i) => i.foodId == foodId && i.variationId == variationId);
    if (_items.isEmpty) _restaurantId = null;
    notifyListeners();
  }

  void updateQuantity(String foodId, int quantity, {String? variationId}) {
    final idx = _items.indexWhere(
      (i) => i.foodId == foodId && i.variationId == variationId,
    );
    if (idx >= 0) {
      if (quantity <= 0) {
        _items.removeAt(idx);
      } else {
        _items[idx] = _items[idx].copyWith(quantity: quantity);
      }
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _restaurantId = null;
    _restaurantName = null;
    notifyListeners();
  }
}
