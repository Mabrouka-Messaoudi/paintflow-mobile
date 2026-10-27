import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'client_summary.dart';

class ClientsRepository {
  ClientsRepository(this._db);

  final SupabaseClient _db;

  Future<List<ClientSummary>> fetchClients() async {
    final rows = await _db
        .from('client_summary')
        .select()
        .order('created_at', ascending: false);
    return rows.map(ClientSummary.fromMap).toList();
  }

  /// Emits the clients list, then re-emits it whenever a client,
  /// payment or purchase changes (Supabase Realtime).
  Stream<List<ClientSummary>> watchClients() {
    late final StreamController<List<ClientSummary>> controller;
    RealtimeChannel? channel;
    Timer? debounce;

    Future<void> load() async {
      try {
        controller.add(await fetchClients());
      } catch (e, st) {
        controller.addError(e, st);
      }
    }

    void scheduleLoad(PostgresChangePayload _) {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 300), load);
    }

    controller = StreamController<List<ClientSummary>>(
      onListen: () {
        load();
        channel = _db.channel('clients-${DateTime.now().microsecondsSinceEpoch}');
        for (final table in ['clients', 'payments', 'purchases']) {
          channel!.onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            callback: scheduleLoad,
          );
        }
        channel!.subscribe();
      },
      onCancel: () async {
        debounce?.cancel();
        if (channel != null) await _db.removeChannel(channel!);
      },
    );
    return controller.stream;
  }

  Future<void> createClient({
    required String fullName,
    String? phone,
    String? address,
    required double agreedAmount,
    required ClientStatus status,
  }) async {
    await _db.from('clients').insert({
      'full_name': fullName,
      'phone': phone,
      'address': address,
      'agreed_amount': agreedAmount,
      'status': status.value,
    });
  }
}

extension ClientAccounts on ClientsRepository {
  /// Calls the `create-client-account` Edge Function (admin only).
  Future<void> createAccount({
    required String clientId,
    required String email,
    required String password,
  }) async {
    await _db.functions.invoke(
      'create-client-account',
      body: {'client_id': clientId, 'email': email, 'password': password},
    );
  }
}

final clientsRepositoryProvider = Provider<ClientsRepository>(
  (ref) => ClientsRepository(Supabase.instance.client),
);

final clientsProvider = StreamProvider.autoDispose<List<ClientSummary>>(
  (ref) => ref.watch(clientsRepositoryProvider).watchClients(),
);
