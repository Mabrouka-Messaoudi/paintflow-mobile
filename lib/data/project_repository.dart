import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/format.dart';
import 'client_summary.dart';
import 'payment.dart';

/// Everything one project screen needs.
class ProjectData {
  const ProjectData(this.client, this.payments);

  final ClientSummary client;
  final List<Payment> payments;
}

class ProjectRepository {
  ProjectRepository(this._db);

  final SupabaseClient _db;

  Future<ProjectData> fetch(String clientId) async {
    final results = await Future.wait<dynamic>([
      _db.from('client_summary').select().eq('id', clientId).single(),
      _db
          .from('payments')
          .select()
          .eq('client_id', clientId)
          .order('paid_at', ascending: false)
          .order('created_at', ascending: false),
    ]);
    final client = ClientSummary.fromMap(results[0] as Map<String, dynamic>);
    final payments = (results[1] as List)
        .map((m) => Payment.fromMap(m as Map<String, dynamic>))
        .toList();
    return ProjectData(client, payments);
  }

  /// Emits the project, then re-emits it on every relevant change (Realtime).
  Stream<ProjectData> watch(String clientId) {
    late final StreamController<ProjectData> controller;
    RealtimeChannel? channel;
    Timer? debounce;

    Future<void> load() async {
      try {
        controller.add(await fetch(clientId));
      } catch (e, st) {
        controller.addError(e, st);
      }
    }

    void schedule(PostgresChangePayload _) {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 250), load);
    }

    controller = StreamController<ProjectData>(
      onListen: () {
        load();
        final ch = _db.channel(
            'project-$clientId-${DateTime.now().microsecondsSinceEpoch}');
        ch.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'clients',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: clientId,
          ),
          callback: schedule,
        );
        // No filter here so that deletions are caught too.
        for (final table in ['payments', 'purchases']) {
          ch.onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            callback: schedule,
          );
        }
        ch.subscribe();
        channel = ch;
      },
      onCancel: () async {
        debounce?.cancel();
        if (channel != null) await _db.removeChannel(channel!);
      },
    );
    return controller.stream;
  }

  Future<void> addPayment({
    required String clientId,
    required double amount,
    required PaymentMethod method,
    String? note,
    required DateTime paidAt,
  }) async {
    await _db.from('payments').insert({
      'client_id': clientId,
      'amount': amount,
      'method': method.value,
      'note': note,
      'paid_at': isoDate(paidAt),
    });
  }

  Future<void> deletePayment(String id) async {
    await _db.from('payments').delete().eq('id', id);
  }
}

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(Supabase.instance.client),
);

final projectProvider =
    StreamProvider.autoDispose.family<ProjectData, String>(
  (ref, clientId) => ref.watch(projectRepositoryProvider).watch(clientId),
);
