import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/format.dart';
import 'client_summary.dart';
import 'payment.dart';
import 'purchase.dart';

const _bucket = 'receipts';

/// Everything one project screen needs.
class ProjectData {
  const ProjectData(this.client, this.payments, this.purchases, this.imageUrls);

  final ClientSummary client;
  final List<Payment> payments;
  final List<Purchase> purchases;

  /// Storage path -> temporary signed URL (the bucket is private).
  final Map<String, String> imageUrls;
}

class ProjectRepository {
  ProjectRepository(this._db);

  final SupabaseClient _db;
  final _random = Random();

  Future<ProjectData> fetch(String clientId) async {
    final results = await Future.wait<dynamic>([
      _db.from('client_summary').select().eq('id', clientId).single(),
      _db
          .from('payments')
          .select()
          .eq('client_id', clientId)
          .order('paid_at', ascending: false)
          .order('created_at', ascending: false),
      _db
          .from('purchases')
          .select()
          .eq('client_id', clientId)
          .order('purchased_at', ascending: false)
          .order('created_at', ascending: false),
    ]);

    final client = ClientSummary.fromMap(results[0] as Map<String, dynamic>);
    final payments = (results[1] as List)
        .map((m) => Payment.fromMap(m as Map<String, dynamic>))
        .toList();
    final purchases = (results[2] as List)
        .map((m) => Purchase.fromMap(m as Map<String, dynamic>))
        .toList();

    final paths = purchases
        .expand((p) => [p.receiptPath, p.itemPhotoPath])
        .whereType<String>()
        .toList();
    // One signed URL per photo, in parallel. A missing file is skipped
    // instead of failing the whole screen.
    final signed = await Future.wait(paths.map((path) async {
      try {
        final url =
            await _db.storage.from(_bucket).createSignedUrl(path, 60 * 60);
        return MapEntry(path, url);
      } catch (_) {
        return null;
      }
    }));
    final urls = Map<String, String>.fromEntries(
        signed.whereType<MapEntry<String, String>>());

    return ProjectData(client, payments, purchases, urls);
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

  // ---------- Payments ----------

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

  // ---------- Purchases ----------

  Future<String> _upload(String clientId, Uint8List bytes, String kind) async {
    final path =
        '$clientId/${kind}_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1000000)}.jpg';
    await _db.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return path;
  }

  Future<void> addPurchase({
    required String clientId,
    required String itemName,
    required double quantity,
    required double unitPrice,
    String? shopName,
    required DateTime purchasedAt,
    Uint8List? receiptBytes,
    Uint8List? itemPhotoBytes,
  }) async {
    final uploads = await Future.wait([
      receiptBytes == null
          ? Future<String?>.value(null)
          : _upload(clientId, receiptBytes, 'receipt'),
      itemPhotoBytes == null
          ? Future<String?>.value(null)
          : _upload(clientId, itemPhotoBytes, 'item'),
    ]);
    final receiptPath = uploads[0];
    final itemPhotoPath = uploads[1];

    try {
      await _db.from('purchases').insert({
        'client_id': clientId,
        'item_name': itemName,
        'quantity': quantity,
        'unit_price': unitPrice,
        'shop_name': shopName,
        'purchased_at': isoDate(purchasedAt),
        'receipt_path': receiptPath,
        'item_photo_path': itemPhotoPath,
      });
    } catch (_) {
      // Don't leave orphan photos in storage if the row failed.
      final orphans = [receiptPath, itemPhotoPath].whereType<String>().toList();
      if (orphans.isNotEmpty) {
        await _db.storage.from(_bucket).remove(orphans);
      }
      rethrow;
    }
  }

  Future<void> deletePurchase(Purchase p) async {
    await _db.from('purchases').delete().eq('id', p.id);
    final paths = [p.receiptPath, p.itemPhotoPath].whereType<String>().toList();
    if (paths.isNotEmpty) {
      try {
        await _db.storage.from(_bucket).remove(paths);
      } catch (_) {
        // The row is gone; a leftover file is harmless.
      }
    }
  }
}

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(Supabase.instance.client),
);

final projectProvider =
    StreamProvider.autoDispose.family<ProjectData, String>(
  (ref, clientId) => ref.watch(projectRepositoryProvider).watch(clientId),
);
