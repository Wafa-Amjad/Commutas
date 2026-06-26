import 'package:dio/dio.dart';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class WalletService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://commutas.onrender.com',
    headers: {'Content-Type': 'application/json'},
  ));

  /// Initiate a wallet top-up. Returns {transaction_id, checkout_url}.
  Future<Map<String, dynamic>?> initiateTopUp({
    required String regNo,
    required double amount,
  }) async {
    try {
      final response = await _dio.post('/api/wallet/topup', data: {
        'user_id': regNo,
        'amount': amount,
      });

      if (response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      developer.log(
        'Top-Up Initiation Failed: ${e.response?.data?['detail'] ?? e.message}',
        name: 'WalletService',
      );
      rethrow;
    }
  }

  /// Track a newly initiated transaction in SharedPreferences
  Future<bool> trackPendingTransaction(String txId, double amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> list = prefs.getStringList('tracked_pending_txs') ?? [];
      list.add('$txId:${amount.toStringAsFixed(0)}');
      await prefs.setStringList('tracked_pending_txs', list);
      return true;
    } catch (e) {
      developer.log('Error tracking pending transaction: $e', name: 'WalletService');
      return false;
    }
  }

  /// Check if tracked pending transactions have transitioned to SUCCESS or FAILED.
  /// If they have, show a sliding overlay notification and return true.
  Future<bool> checkPendingTransactions(String token, BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> list = prefs.getStringList('tracked_pending_txs') ?? [];
      if (list.isEmpty) return false;

      // Fetch latest transaction history
      final history = await fetchTransactionHistory(token: token);
      if (history.isEmpty) return false;

      final List<String> updatedList = List.from(list);
      bool stateChanged = false;

      for (final item in list) {
        final parts = item.split(':');
        if (parts.length != 2) continue;
        final txId = parts[0];
        final amount = parts[1];

        // Find in history
        final matchingTx = history.firstWhere(
          (tx) => tx['transaction_id'] == txId,
          orElse: () => {},
        );

        if (matchingTx.isNotEmpty) {
          final status = matchingTx['status'];
          if (status == 'SUCCESS') {
            updatedList.remove(item);
            stateChanged = true;
          } else if (status == 'FAILED' || status == 'ERROR') {
            updatedList.remove(item);
            stateChanged = true;
          }
        }
      }

      if (stateChanged) {
        await prefs.setStringList('tracked_pending_txs', updatedList);
      }
      return stateChanged;
    } catch (e) {
      developer.log('Error checking pending transactions: $e', name: 'WalletService');
      return false;
    }
  }

  /// Fetch the current wallet balance. Requires JWT token.
  /// Returns the balance as a double, defaults to 0.0 on error.
  Future<double> fetchWalletBalance({required String token}) async {
    try {
      final response = await _dio.get(
        '/api/wallet/balance',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data != null) {
        return (response.data['balance'] as num).toDouble();
      }
      return 0.0;
    } on DioException catch (e) {
      developer.log(
        'Fetch Balance Failed: ${e.response?.data?['detail'] ?? e.message}',
        name: 'WalletService',
      );
      return 0.0;
    }
  }

  /// Fetch the transaction history for the current student. Requires JWT token.
  /// Returns a list of transaction maps with keys:
  ///   transaction_id, amount, status, created_at
  Future<List<Map<String, dynamic>>> fetchTransactionHistory({
    required String token,
  }) async {
    try {
      final response = await _dio.get(
        '/api/wallet/transactions',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data is List) {
        return List<Map<String, dynamic>>.from(
          (response.data as List).map((item) => Map<String, dynamic>.from(item)),
        );
      }
      return [];
    } on DioException catch (e) {
      developer.log(
        'Fetch Transactions Failed: ${e.response?.data?['detail'] ?? e.message}',
        name: 'WalletService',
      );
      return [];
    }
  }
}
