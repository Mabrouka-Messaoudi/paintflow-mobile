import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_theme.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  runApp(const ProviderScope(child: PaintFlowApp()));
}

class PaintFlowApp extends StatelessWidget {
  const PaintFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PaintFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const ConnectionCheckScreen(),
    );
  }
}

/// Temporary screen: checks the Supabase connection (replaced in step 4).
class ConnectionCheckScreen extends StatefulWidget {
  const ConnectionCheckScreen({super.key});

  @override
  State<ConnectionCheckScreen> createState() => _ConnectionCheckScreenState();
}

class _ConnectionCheckScreenState extends State<ConnectionCheckScreen> {
  late final Future<int> _check = _countVisibleClients();

  Future<int> _countVisibleClients() async {
    final rows = await Supabase.instance.client
        .from('client_summary')
        .select('id');
    return rows.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FutureBuilder<int>(
            future: _check,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const CircularProgressIndicator();
              }
              if (snap.hasError) {
                return Text('خطأ: ${snap.error}', textAlign: TextAlign.center);
              }
              return Text(
                'متصل بـ Supabase ✅\nعدد الحرفاء المرئيين: ${snap.data}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              );
            },
          ),
        ),
      ),
    );
  }
}
