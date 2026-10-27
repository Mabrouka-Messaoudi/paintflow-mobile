import 'package:intl/intl.dart';

final _money = NumberFormat('#,##0.###', 'en_US');

/// 12000 -> "12,000 د.ت"
String money(num value) => '${_money.format(value)} د.ت';

/// Tunisian month names.
const _months = [
  'جانفي', 'فيفري', 'مارس', 'أفريل', 'ماي', 'جوان',
  'جويلية', 'أوت', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

/// 2026-10-27 -> "27 أكتوبر 2026"
String arDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// 2026-10-27 -> "2026-10-27" (for the database)
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
