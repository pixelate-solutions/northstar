import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'cache/hive_adapters.dart';
import 'cache/trip_cache.dart';
import 'core/services/notification_service.dart';
import 'data/supabase_client.dart';
import 'northstar_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await registerHiveAdapters();
  await TripCache.open();
  await initSupabase();
  await initNotifications();
  runApp(
    const ProviderScope(
      child: NorthstarApp(),
    ),
  );
}
