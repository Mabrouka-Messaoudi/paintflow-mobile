import 'package:intl/intl.dart';

final _money = NumberFormat('#,##0.###', 'en_US');

/// 12000 -> "12,000 د.ت"
String money(num value) => '${_money.format(value)} د.ت';
