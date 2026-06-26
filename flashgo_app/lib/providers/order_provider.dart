// lib/providers/order_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class OrderState {
  final List<dynamic> orders;
  final List<dynamic> nearbyOrders;
  final Map<String, dynamic>? currentOrder;
  final bool    isLoading;
  final String? error;

  const OrderState({
    this.orders       = const [],
    this.nearbyOrders = const [],
    this.currentOrder,
    this.isLoading = false,
    this.error,
  });

  OrderState copyWith({
    List<dynamic>?          orders,
    List<dynamic>?          nearbyOrders,
    Map<String, dynamic>?   currentOrder,
    bool?                   isLoading,
    String?                 error,
  }) {
    return OrderState(
      orders:        orders        ?? this.orders,
      nearbyOrders:  nearbyOrders  ?? this.nearbyOrders,
      currentOrder:  currentOrder  ?? this.currentOrder,
      isLoading:     isLoading     ?? this.isLoading,
      error:         error         ?? this.error,
    );
  }
}

class OrderNotifier extends StateNotifier<OrderState> {
  OrderNotifier() : super(const OrderState());

  Future<void> fetchMyOrders() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await ApiService.get(ApiConfig.ordersMine);
      state = state.copyWith(
        isLoading: false,
        orders:    data['orders'] ?? [],
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  Future<void> fetchNearbyOrders(double lat, double lng) async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await ApiService.get(
        '${ApiConfig.ordersNearby}?lat=$lat&lng=$lng',
      );
      state = state.copyWith(
        isLoading:    false,
        nearbyOrders: data['orders'] ?? [],
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  Future<Map<String, dynamic>?> createOrder(
      Map<String, dynamic> body) async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await ApiService.post(ApiConfig.orders, body);
      state = state.copyWith(isLoading: false);
      return data;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return null;
    }
  }

  Future<Map<String, dynamic>?> acceptOrder(
      String orderId, String deviceId) async {
    try {
      final data = await ApiService.patch(
        '${ApiConfig.orders}/$orderId/accept',
        {'device_id': deviceId},
      );
      return data;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return null;
    }
  }

  Future<bool> validateOtp(
      String orderId, String otpInput, String driverId) async {
    try {
      await ApiService.patch(
        '${ApiConfig.orders}/$orderId/validate-otp',
        {'otp_input': otpInput, 'driver_id': driverId},
      );
      return true;
    } on ApiException {
      return false;
    }
  }
}

final orderProvider = StateNotifierProvider<OrderNotifier, OrderState>(
  (ref) => OrderNotifier(),
);