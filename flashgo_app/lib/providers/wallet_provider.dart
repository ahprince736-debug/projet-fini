// lib/providers/wallet_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class WalletState {
  final int            balance;
  final List<dynamic>  transactions;
  final bool           isLoading;
  final String?        error;

  const WalletState({
    this.balance      = 0,
    this.transactions = const [],
    this.isLoading    = false,
    this.error,
  });

  WalletState copyWith({
    int?           balance,
    List<dynamic>? transactions,
    bool?          isLoading,
    String?        error,
  }) {
    return WalletState(
      balance:      balance      ?? this.balance,
      transactions: transactions ?? this.transactions,
      isLoading:    isLoading    ?? this.isLoading,
      error:        error        ?? this.error,
    );
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier() : super(const WalletState());

  Future<void> fetchWallet() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await ApiService.get(ApiConfig.wallet);
      state = state.copyWith(
        isLoading:    false,
        balance:      data['balance']      ?? 0,
        transactions: data['transactions'] ?? [],
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  Future<bool> requestWithdrawal({
    required int    amount,
    required String momoNumber,
    required String network,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await ApiService.post(ApiConfig.walletWithdraw, {
        'amount':      amount,
        'momo_number': momoNumber,
        'network':     network,
      });
      state = state.copyWith(isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>(
  (ref) => WalletNotifier(),
);