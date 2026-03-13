import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:subtrack/src/app.dart';
import 'package:subtrack/src/features/notifications/application/notification_service.dart';

const _supabaseUrl = 'https://rbkqsklkjdmxiekxapaa.supabase.co';
const _supabaseKey = 'sb_publishable_Ss4JQN0F1ypxbS2G3N2G6w_g25qp5QT';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Notifications
  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.requestPermissions();

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseKey,
    authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
  );

  runApp(const ProviderScope(child: SubTrackApp()));
}