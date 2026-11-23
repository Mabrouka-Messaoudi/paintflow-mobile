import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/format.dart';
import 'payment.dart';
import 'purchase.dart';

double _num(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.parse(v.toString());
}

class Expense {
  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.spentAt,
    this.note,
  });

  final String id;
  final String title;
  final double amount;
  final DateTime spentAt;
  final String? note;

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
        id: m['id'] as String,
        title: m['title'] as String,
        amount: _num(m['amount']),
        spentAt: DateTime.parse(m['spent_at'] as String),
        note: m['note'] as String?,
      );
}

class Wage {
  const Wage({
    required this.id,
    required this.workerName,
    required this.amount,
    required this.paidAt,
    this.note,
  });

  final String id;
  final String workerName;
  final double amount;
  final DateTime paidAt;
  final String? note;

  factory Wage.fromMap(Map<String, dynamic> m) => Wage(
        id: m['id'] as String,
        workerName: m['worker_name'] as String,
        amount: _num(m['amount']),
        paidAt: DateTime.parse(m['paid_at'] as String),
        note: m['note'] as String?,
      );
}

class FinanceRepository {
  FinanceRepository(this._db);

  final SupabaseClient _db;

  Future<List<Payment>> payments() async {
    final rows =
        await _db.from('payments').select().order('paid_at', ascending: false);
    return rows.map(Payment.fromMap).toList();
  }

  Future<List<Purchase>> purchases() async {
    final rows = await _db
        .from('purchases')
        .select()
        .order('purchased_at', ascending: false);
    return rows.map(Purchase.fromMap).toList();
  }

  Future<List<Expense>> expenses() async {
    final rows = await _db
        .from('expenses')
        .select()
        .order('spent_at', ascending: false);
    return rows.map(Expense.fromMap).toList();
  }

  Future<List<Wage>> wages() async {
    final rows = await _db
        .from('worker_wages')
        .select()
        .order('paid_at', ascending: false);
    return rows.map(Wage.fromMap).toList();
  }

  Future<void> addExpense({
    required String title,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    await _db.from('expenses').insert({
      'title': title,
      'amount': amount,
      'spent_at': isoDate(date),
      'note': note,
    });
  }

  Future<void> deleteExpense(String id) async {
    await _db.from('expenses').delete().eq('id', id);
  }

  Future<void> addWage({
    required String workerName,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    await _db.from('worker_wages').insert({
      'worker_name': workerName,
      'amount': amount,
      'paid_at': isoDate(date),
      'note': note,
    });
  }

  Future<void> deleteWage(String id) async {
    await _db.from('worker_wages').delete().eq('id', id);
  }
}

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => FinanceRepository(Supabase.instance.client),
);

final allPaymentsProvider = FutureProvider.autoDispose<List<Payment>>(
  (ref) => ref.watch(financeRepositoryProvider).payments(),
);

final allPurchasesProvider = FutureProvider.autoDispose<List<Purchase>>(
  (ref) => ref.watch(financeRepositoryProvider).purchases(),
);

final expensesProvider = FutureProvider.autoDispose<List<Expense>>(
  (ref) => ref.watch(financeRepositoryProvider).expenses(),
);

final wagesProvider = FutureProvider.autoDispose<List<Wage>>(
  (ref) => ref.watch(financeRepositoryProvider).wages(),
);
